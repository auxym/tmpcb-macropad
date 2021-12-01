"""
Generate Raspberry Pi Pico land pattern

"""

import json

from uuid import uuid5, UUID

base_pkg = json.loads("""
{
    "arcs": {},
    "default_model": "00000000-0000-0000-0000-000000000000",
    "dimensions": {},
    "grid_settings": {
        "current": {
            "mode": "square",
            "name": "",
            "origin": [
                0,
                0
            ],
            "spacing_rect": [
                1000000,
                1000000
            ],
            "spacing_square": 1000000
        },
        "grids": {}
    },
    "junctions": {},
    "keepouts": {},
    "lines": {},
    "manufacturer": "",
    "models": {},
    "name": "sc0915_smd",
    "pads": {
        "707e1564-e4b5-47cb-ad86-5e18c74a97f8": {
            "name": "1",
            "padstack": "d2aad97e-e7b2-40f1-9ffe-2bc7e6df4c56",
            "parameter_set": {
                "pad_height": 3200000,
                "pad_width": 1600000
            },
            "placement": {
                "angle": 49152,
                "mirror": false,
                "shift": [
                    810000,
                    1370000
                ]
            }
        }
    },
    "parameter_program": "",
    "parameter_set": {},
    "polygons": {},
    "rules": {
        "clearance_package": {
            "clearance_silkscreen_cu": 200000,
            "clearance_silkscreen_pkg": 200000,
            "enabled": true,
            "order": -1
        },
        "package_checks": {
            "enabled": true,
            "order": -1
        }
    },
    "tags": [],
    "texts": {},
    "type": "package",
    "uuid": "8c98e2da-a329-4b9e-913c-b640ed70ee82"
}
""")

pkg_uuid = UUID(base_pkg["uuid"])

pico_half_round_pad = {
    "padstack": "d2aad97e-e7b2-40f1-9ffe-2bc7e6df4c56",
    "parameter_set": {
        "pad_height": 3200000,
        "pad_width": 1600000
    },
}

pico_rect_pad = {
    "padstack": "8e762581-e1b1-4fb4-81d3-7f8a1cabb97f",
    "parameter_set": {
        "corner_radius": 200000,
        "pad_height": 3200000,
        "pad_width": 1600000
    },
}


pads = {}

for i in range(1, 41):
    # Generate pads 1-40

    if i <= 20:
        y = 52.17 - 2.54 * i
        x = 0.81
        rot = 16384 * 3
    else:
        y = 1.37 + 2.54 * (i - 21)
        x = 0.81 + 19.38
        rot = 16384

    p = {
        "name": str(i),
        "placement": {
            "angle": rot,
            "mirror": False,
            "shift": [
                int(x * 1E6),
                int(y * 1E6),
            ]
        }
    }

    if i in [3, 8, 13, 18, 23, 28, 33, 38]:
        # Rectangular pad for GND
        p.update(pico_rect_pad)
    else:
        p.update(pico_half_round_pad)

    pad_uuid = str(uuid5(pkg_uuid, str(i)))
    pads[pad_uuid] = p

for j, dbg_pad in enumerate(["D1", "D2", "D3"]):
    y = 0.8
    x = 7.96 + 2.54 * j
    p = {
        "name": dbg_pad,
        "placement": {
            "angle": 0,
            "mirror": False,
            "shift": [
                int(x * 1E6),
                int(y * 1E6),
            ]
        }
    }

    if dbg_pad == "D2":
        p.update(pico_rect_pad)
    else:
        p.update(pico_half_round_pad)

    pad_uuid = str(uuid5(pkg_uuid, dbg_pad))
    pads[pad_uuid] = p


print(pads)

base_pkg["pads"] = pads

fname = "D:/Francis/Documents/Source/horizon-pool/packages/manufacturer/raspberry/sc0915_smd/package.json"

with open(fname, "wt") as f:
    json.dump(base_pkg, f, indent=4, sort_keys=True)
