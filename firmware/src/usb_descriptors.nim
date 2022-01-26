import picostdlib/tusb

const Usb_Ep0_Size = 64'u8 # Must match CFG_TUD_ENDPOINT0_SIZE value in tusb_config.h

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
