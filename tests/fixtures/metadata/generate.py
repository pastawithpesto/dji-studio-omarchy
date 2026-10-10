"""Reproduce synthetic fixtures with an independent Python protobuf runtime.

Requires protobuf 6.31.0. In the reconstruction workspace, --protobuf-wheel may
point to tools/ghidra_12.1.4_PUBLIC/Ghidra/Debug/Debugger-rmi-trace/pypkg/dist/
protobuf-6.31.0-py3-none-any.whl. No camera/vendor runtime is used.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import sys

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--protobuf-wheel", type=Path)
parser.add_argument("--output-dir", type=Path, default=Path(__file__).resolve().parent)
args = parser.parse_args()
if args.protobuf_wheel:
    sys.path.insert(0, str(args.protobuf_wheel.resolve()))
os.environ["PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION"] = "python"
from google.protobuf import descriptor_pb2, descriptor_pool, message_factory
from google.protobuf import __version__

assert __version__ == "6.31.0", __version__
source_root = Path(__file__).resolve().parents[3]
descriptor = (source_root / "descriptors/dji-metadata-descriptors.pb").read_bytes()
descriptor_sha = hashlib.sha256(descriptor).hexdigest()
assert descriptor_sha == "45bdd29930f3d10f46ed51a7ee3b8917e3806a4bc425f136c034908c4fc578bb"
pool = descriptor_pool.DescriptorPool()
for file in descriptor_pb2.FileDescriptorSet.FromString(descriptor).file:
    pool.Add(file)
args.output_dir.mkdir(parents=True, exist_ok=True)
records = []


def cls(package):
    return message_factory.GetMessageClass(pool.FindMessageTypeByName(package + ".ProductMeta"))


def quaternion(message, values):
    for component, value in zip("wxyz", values):
        setattr(message, "quaternion_" + component, value)


def fixture(name, package, data, expectation, classification="descriptor_synthetic"):
    # Parse every accepted fixture with Python, independently of the Rust tests.
    parsed = cls(package).FromString(data)
    if "proto_file_name" in expectation:
        assert parsed.clip_meta.clip_meta_header.proto_file_name == expectation["proto_file_name"]
    if "frame_timestamp" in expectation:
        assert parsed.frame_meta.frame_meta_header.frame_timestamp == expectation["frame_timestamp"]
    if "frame_seq_num" in expectation:
        assert parsed.frame_meta.frame_meta_header.frame_seq_num == expectation["frame_seq_num"]
    if "presence" in expectation:
        assert [n for n in ["clip_meta", "stream_meta", "frame_meta"] if parsed.HasField(n)] == expectation["presence"]
    (args.output_dir / name).write_bytes(data)
    records.append({"file": name, "package": package, "classification": classification,
                    "sha256": hashlib.sha256(data).hexdigest(), "length": len(data),
                    "wire_hex": data.hex(), "expected": expectation, "python_accepts": True})


UNKNOWN = bytes.fromhex("a006b424aa0606667574757265b50678563412b9068877665544332211c3060801c406")
NESTED_UNKNOWN = bytes.fromhex("98062a")  # field 99, varint 42
FIRST_QUATERNION = (1.0, 0.25, -0.5, 0.75)
SECOND_QUATERNION = (-1.0, 0.0, 0.5, -0.25)
for package, filename in [("oqb101", "dvtm_oqb101.proto"), ("wab530", "dvtm_eagle4_wab530.proto")]:
    message = cls(package)()
    header = message.clip_meta.clip_meta_header
    header.proto_file_name = filename
    header.library_proto_version = "synthetic-library"
    header.clip_timestamp = 18446744073709551613
    header.MergeFromString(NESTED_UNKNOWN)
    pano = message.stream_meta.pano_dewarp_params
    pano.native_refine_slave.fx = 120.5
    pano.native_refine_slave.width = 1920.0
    pano.native_refine_slave.p.extend([0.125, -0.25, 0.5])  # packed repeated floats
    pano.native_refine_master.fx = 125.5
    message.stream_meta.extri_lens_mode.mode = 1
    frame = message.frame_meta.frame_meta_header
    frame.frame_seq_num = 11
    frame.frame_timestamp = 9007199254741115
    frame.stream_id = 2
    frame.check_code_enable = True
    frame.check_code_type = 1
    frame.check_code = 4660
    camera = message.frame_meta.camera_frame_meta
    camera.current_underwater_confidence.current_underwater_confidence = 7
    quaternion(camera.camera_attitude, FIRST_QUATERNION)
    camera.camera_attitude.MergeFromString(NESTED_UNKNOWN)
    for component, value in zip("xyz", [1.0, 2.0, 3.0]):
        setattr(camera.camera_acc, "accelerometer_" + component, value)
    fused = message.frame_meta.imu_frame_meta.IMU_attitude_after_fusion
    fused.current_frame.timestamp = 4294967294
    fused.current_frame.vsync = 5
    fused.current_frame.offset = 0.125
    quaternion(fused.current_frame.attitude.add(), FIRST_QUATERNION)
    quaternion(fused.current_frame.attitude.add(), SECOND_QUATERNION)
    fused.prev_frame.timestamp = 2
    fused.next_frame.timestamp = 3
    message.frame_meta.imu_frame_meta.IMU_vsync_pos.vsync_pos = 17
    if package == "wab530":
        single = message.frame_meta.imu_frame_meta.IMU_single_attitude_after_fusion
        single.timestamp = 78
        quaternion(single.attitude.add(), SECOND_QUATERNION)
        raw = message.frame_meta.imu_frame_meta.IMU_single_attitude_raw_data
        raw.timestamp = 9007199254741191
        sample = raw.imu_raw_data.add()
        for field, value in zip(["gyro_x", "gyro_y", "gyro_z", "acc_x", "acc_y", "acc_z"],
                                [0.125, 0.25, 0.5, 1.25, 1.5, 1.75]):
            setattr(sample, field, value)
    expected = {"proto_file_name": filename, "clip_timestamp": 18446744073709551613,
                "frame_timestamp": 9007199254741115, "frame_seq_num": 11,
                "fused_timestamp_uint32": 4294967294,
                "camera_quaternion_wxyz": FIRST_QUATERNION,
                "fused_quaternions_wxyz": [FIRST_QUATERNION, SECOND_QUATERNION],
                "presence": ["clip_meta", "stream_meta", "frame_meta"],
                "nested_unknown_field": {"number": 99, "varint": 42},
                "pano_field": 6 if package == "oqb101" else 5,
                "camera_attitude_field": 9 if package == "oqb101" else 22}
    data = message.SerializeToString(deterministic=True)
    fixture(package + "-complete.pb", package, data, expected)
    fixture(package + "-unknown.pb", package, data + UNKNOWN,
            dict(expected, top_unknown_field_numbers=[100, 101, 102, 103, 104]))
    for name in ["clip_meta", "stream_meta", "frame_meta"]:
        partial = cls(package)()
        getattr(partial, name).CopyFrom(getattr(message, name))
        fixture(package + "-" + name + "-only.pb", package, partial.SerializeToString(deterministic=True),
                {"presence": [name]})

fixture("empty.pb", "oqb101", b"", {"presence": []})
fixture("empty-frame.pb", "oqb101", bytes.fromhex("1a00"), {"presence": ["frame_meta"]})
fixture("all-unknown.pb", "oqb101", UNKNOWN, {"presence": [], "top_unknown_field_numbers": [100, 101, 102, 103, 104]})
fixture("noncanonical-unknown.pb", "oqb101", bytes.fromhex("a006b4a400"),
        {"presence": [], "top_unknown_field_numbers": [100], "varint": 4660})
fixture("duplicate-frame.pb", "oqb101", bytes.fromhex("1a040a0208011a070a05080210c801"),
        {"presence": ["frame_meta"], "frame_seq_num": 2, "frame_timestamp": 200}, "standard_protobuf_merge")

# These cases probe syntax and pinned-runtime policies, independently classified
# here. Legal wrong-wire and excessive depth acceptance may differ by runtime.
probes = {
    "truncated-key": b"\x80",
    "zero-key": b"\x00",
    "reserved-wire6": b"\x0e",
    "reserved-wire7": b"\x0f",
    "truncated-varint": bytes.fromhex("a00680"),
    "overflow-varint": bytes.fromhex("a006") + b"\xff" * 9 + b"\x02",
    "truncated-message": bytes.fromhex("1a050a00"),
    "invalid-nested-key": bytes.fromhex("1a0100"),
    "invalid-utf8": bytes.fromhex("0a050a030a01ff"),
    "malformed-tail": bytes.fromhex("1a00ff"),
    "overflow-length": b"\x1a" + b"\xff" * 9 + b"\x02",
    "mismatched-group": bytes.fromhex("c306cc06"),
    "unclosed-group": bytes.fromhex("c3060801"),
    "unexpected-end-group": bytes.fromhex("c406"),
    "recursive-groups101": bytes.fromhex("c306") * 101 + bytes.fromhex("c406") * 101,
    "known-wrong-wire": bytes.fromhex("0801"),
}
for name, data in probes.items():
    error = None
    try:
        cls("oqb101").FromString(data)
    except Exception as exc:
        error = type(exc).__name__ + ": " + str(exc)
    (args.output_dir / (name + ".pb")).write_bytes(data)
    records.append({"file": name + ".pb", "package": "oqb101", "classification": "wire_or_runtime_policy_probe",
                    "sha256": hashlib.sha256(data).hexdigest(), "length": len(data), "wire_hex": data.hex(),
                    "python_accepts": error is None, "python_error": error})

manifest = {"generator": "generate.py", "protobuf_version": __version__, "implementation": "python",
            "descriptor_set_sha256": descriptor_sha,
            "source_binary_sha256": "9450a9631b40037ec8c9bbd874f56e455264ed408a93d66168235b68c4383e42",
            "reference_build": "1.0.0.30839", "fixtures": records,
            "limitations": "Constructed independent Python descriptor fixtures, not captured camera/Windows/vendor behavior. Wrong-wire and depth policies can differ between runtimes. Timestamp units and coordinate frames are unknown."}
(args.output_dir / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
print(f"Generated {len(records)} fixtures; descriptor SHA-256 {descriptor_sha}")
