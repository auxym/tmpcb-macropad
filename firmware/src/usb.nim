import picostdlib/tusb

type UsbMountState* = enum usbMounted, usbSuspended, usbUnmounted

var usbState: UsbMountState = usbUnmounted

const
  Usb_Ep0_Size = 64'u8 # Must match CFG_TUD_ENDPOINT0_SIZE value in tusb_config.h

  usbser* = 0.UsbSerialInterface
  hid* = 0.UsbHidInterface

{.push header: "usb_descriptors.h".}
let
  keyboardReportId* {.importc: "REPORT_ID_KEYBOARD".}: uint8
  mouseReportId* {.importc: "REPORT_ID_MOUSE".}: uint8
{.pop.}

setDeviceDescriptor:
  UsbDeviceDescriptor(
    len: sizeof(UsbDeviceDescriptor).uint8,
    descType: UsbDescriptorType.device,
    binCodeUsb: 0x0200,
    class: UsbDeviceClass.misc,
    subclass: UsbMiscSubclass.common,
    protocol: UsbMiscProtocol.iad,
    maxPacketSize: Usb_Ep0_Size,
    vendorId: 0xCAFE,
    productId: 0x4005,
    binaryCodeDev: 0x0100,
    manufacturer: 1,
    product: 2,
    serialNumber: 3,
    numConfigurations: 1
  )

proc getUsbState*(): UsbMountState = usbState

hidGetReportCallback(instance, reportId, reportType, buffer, reqLen):
  discard

hidSetReportCallback(instance, reportId, reportType, buffer, reqLen):
  discard

mountCallback:
  usbState = usbMounted

unmountCallback:
  usbState = usbUnmounted

suspendCallback(wakeUpEnabled):
  usbState = usbSuspended

resumeCallback:
  usbState = usbMounted
