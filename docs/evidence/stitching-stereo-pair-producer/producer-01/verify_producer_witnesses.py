#!/usr/bin/env python3
"""Read-only PE byte witnesses for the EisGetStereoPair producer boundary."""
from __future__ import annotations
import hashlib, json, struct, subprocess
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path('/home/violence/Projects/dji-studio-omarchy')
CHECKOUT = Path('/home/violence/Work/stitching-cache-verification-20261012/source')
EXPECTED_HEAD = '886e01f255877967c6cbd6b360e72f3dee4ec28e'
EXPECTED_MAIN = '13357262099643200bffa435bce7a14528cf8d14'
SRC = ROOT / 'extracted/1.0.0.30839'
VINCE = SRC / 'VinceEditor.dll'
EIS = SRC / 'dual_fisheye_video_eis_win.dll'
OUT = Path(__file__).with_name('PE-WITNESSES.json')
EXPECTED = {
    VINCE: '9450a9631b40037ec8c9bbd874f56e455264ed408a93d66168235b68c4383e42',
    EIS: 'e35f7397b9b6ad9b9e453ff01bc1f34e3ea9470bd6bc2a6b5bbdd637dac4e09a',
}
EIS_NAME = b'?EisGetStereoPair@DUALFISHEYEVIDEOEIS@@YA?AUdata_feed_stereo_pair@@PEAXHAEBUFrameMetaOfIMU@1@11JJJUSensorTemperature@1@HUFlightPoseNavi@1@@Z'

class PE:
    def __init__(self, path: Path):
        self.path = path
        self.data = path.read_bytes()
        self.sha = hashlib.sha256(self.data).hexdigest()
        if self.data[:2] != b'MZ': raise ValueError(f'{path}: missing MZ')
        self.pe = struct.unpack_from('<I', self.data, 0x3c)[0]
        if self.data[self.pe:self.pe+4] != b'PE\0\0': raise ValueError(f'{path}: missing PE signature')
        coff = self.pe + 4
        self.machine, self.nsec, self.timestamp, _, _, self.opt_size, self.characteristics = struct.unpack_from('<HHIIIHH', self.data, coff)
        self.opt = coff + 20
        if struct.unpack_from('<H', self.data, self.opt)[0] != 0x20b: raise ValueError(f'{path}: not PE32+')
        self.base = struct.unpack_from('<Q', self.data, self.opt+24)[0]
        self.num_dirs = struct.unpack_from('<I', self.data, self.opt+108)[0]
        self.directories = [struct.unpack_from('<II', self.data, self.opt+112+8*i) for i in range(min(self.num_dirs,16))]
        self.sections = []
        secpos = self.opt + self.opt_size
        for i in range(self.nsec):
            pos=secpos+i*40
            name=self.data[pos:pos+8].split(b'\0',1)[0].decode('ascii')
            vsize,rva,rsize,raw=struct.unpack_from('<IIII',self.data,pos+8)
            self.sections.append({'name':name,'virtual_size':vsize,'rva':rva,'raw_size':rsize,'raw':raw})
    def section(self, rva):
        for s in self.sections:
            if s['rva'] <= rva < s['rva'] + max(s['virtual_size'],s['raw_size']): return s
        return None
    def rva_fileoff(self, rva, size=1):
        s=self.section(rva)
        if not s: raise ValueError(f'{self.path}: unmapped RVA {rva:#x}')
        delta=rva-s['rva']
        if delta+size>s['raw_size']: raise ValueError(f'{self.path}: RVA {rva:#x} has no raw backing')
        return s['raw']+delta
    def bytes_rva(self, rva, size):
        off=self.rva_fileoff(rva,size)
        return off,self.data[off:off+size]
    def bytes_va(self, va, size): return self.bytes_rva(va-self.base,size)
    def cstr_rva(self, rva):
        off=self.rva_fileoff(rva)
        end=self.data.find(b'\0',off)
        if end < 0: raise ValueError('unterminated string')
        return self.data[off:end]
    def exports(self):
        rva,size=self.directories[0]
        if not rva: return []
        off=self.rva_fileoff(rva,40)
        _,_,_,_,name_rva,base,nfunc,nname,funcs,names,ords=struct.unpack_from('<IIHHIIIIIII',self.data,off)
        out=[]
        for i in range(nname):
            nrva=struct.unpack_from('<I',self.data,self.rva_fileoff(names+4*i,4))[0]
            name=self.cstr_rva(nrva)
            oi=struct.unpack_from('<H',self.data,self.rva_fileoff(ords+2*i,2))[0]
            frva=struct.unpack_from('<I',self.data,self.rva_fileoff(funcs+4*oi,4))[0]
            out.append({'name_bytes':name,'ordinal':base+oi,'rva':frva})
        return out
    def imports(self):
        rva,size=self.directories[1]
        out=[]
        if not rva: return out
        off=self.rva_fileoff(rva,20)
        while True:
            oft,stamp,chain,name_rva,iat=struct.unpack_from('<IIIII',self.data,off)
            if not any((oft,stamp,chain,name_rva,iat)): break
            dll=self.cstr_rva(name_rva).decode('ascii')
            thunk=oft or iat
            symbols=[]
            idx=0
            while True:
                val=struct.unpack_from('<Q',self.data,self.rva_fileoff(thunk+8*idx,8))[0]
                if val==0: break
                if val>>63: sym='#'+str(val&0xffff)
                else:
                    noff=self.rva_fileoff(val,3)
                    nend=self.data.find(b'\0',noff+2)
                    if nend<0: raise ValueError('unterminated import name')
                    sym=self.data[noff+2:nend].decode('ascii')
                symbols.append({'symbol':sym,'iat_va':hex(self.base+iat+8*idx)})
                idx+=1
            out.append({'dll':dll,'symbols':symbols})
            off+=20
        return out

def git(*args):
    return subprocess.check_output(['git','-C',str(CHECKOUT),*args],text=True).strip()
repo_head=git('rev-parse','HEAD')
repo_main=git('rev-parse','origin/main')
repo_branch=git('branch','--show-current')
repo_dirty=bool(git('status','--porcelain'))
if repo_head!=EXPECTED_HEAD or repo_main!=EXPECTED_MAIN or repo_dirty:
    raise ValueError(f'checkout pin/state mismatch: {repo_head=} {repo_main=} {repo_dirty=}')
pins={}
for path,expected in EXPECTED.items():
    pe=PE(path)
    if pe.sha != expected: raise ValueError(f'{path.name} hash mismatch: {pe.sha}')
    pins[path.name]={'sha256':pe.sha,'size_bytes':len(pe.data),'image_base':hex(pe.base),'machine':hex(pe.machine),'sections':pe.sections}

v=PE(VINCE); eis=PE(EIS)
found=[x for x in eis.exports() if x['name_bytes']==EIS_NAME]
if len(found)!=1: raise ValueError(f'expected exactly one decorated export; got {len(found)}')
eis_export=found[0]
if (eis_export['ordinal'],eis_export['rva']) != (26,0x1474): raise ValueError(f'unexpected export coordinates: {eis_export}')
export_section=eis.section(eis_export['rva'])
if not export_section or export_section['name']!='.text' or export_section['raw_size']!=0: raise ValueError('expected export RVA inside virtual-only .text')
# Verify exact import identity and IAT address from original VinceEditor PE.
import_rows=[(im['dll'],sym) for im in v.imports() for sym in im['symbols'] if sym['symbol']==EIS_NAME.decode('ascii')]
if len(import_rows)!=1 or import_rows[0][0].lower()!='dual_fisheye_video_eis_win.dll' or import_rows[0][1]['iat_va']!='0x180670988':
    raise ValueError(f'import identity mismatch: {import_rows}')
# Fixed instruction-byte ranges; these pin R15 initialization, the call boundary, and reads.
landmarks=[
    ('incoming_rcx_copied_to_r15',0x18013CD75,'4c8bf9'),
    ('R15_plus_24_written_0x780',0x18013D187,'41c7472480070000'),
    ('R15_plus_28_written_0x780',0x18013D18F,'41c7472880070000'),
    ('helper_called_with_R15_as_RC',0x18013D23F,'498bcfe8f9a4ffff'),
    ('R15_plus_28_loaded_for_record',0x18013D424,'418b4f28'),
    ('R15_plus_24_loaded_for_record',0x18013D42E,'418b5724'),
    ('Eis_IAT_indirect_call',0x18013D409,'ff1579355300'),
]
landmark_rows=[]
for label,va,hexbytes in landmarks:
    want=bytes.fromhex(hexbytes); off,got=v.bytes_va(va,len(want))
    if got!=want: raise ValueError(f'{label} byte mismatch at {va:#x}: {got.hex()}')
    landmark_rows.append({'label':label,'va':hex(va),'file_offset':hex(off),'bytes_hex':got.hex()})
# Read the function table record that bounds the complete helper body.
pdata=next(s for s in v.sections if s['name']=='.pdata')
pdata_bytes=v.data[pdata['raw']:pdata['raw']+pdata['raw_size']]
records=[]
for pos in range(0,len(pdata_bytes)-11,12):
    begin,end,unwind=struct.unpack_from('<III',pdata_bytes,pos)
    if begin==0x137740: records.append({'file_offset':hex(pdata['raw']+pos),'begin_rva':hex(begin),'end_rva':hex(end),'unwind_rva':hex(unwind)})
if len(records)!=1 or records[0]['end_rva']!='0x1378a8': raise ValueError(f'unexpected helper runtime function record: {records}')
helper_off,helper_bytes=v.bytes_rva(0x137740,0x1378a8-0x137740)
# The complete .pdata-bounded body has exact raw bytes and no direct access to offsets 0x24/0x28.
helper_hex=helper_bytes.hex()
helper_disp_start,helper_disasm=0x180137740,Path(__file__).with_name('helper.objdump.txt').read_text(encoding='utf-8')
if '180137740' not in helper_disasm or '1801378a3' not in helper_disasm: raise ValueError('helper disassembly capture is incomplete')
# Independently bind selected caller writes/reads in a continuous file-backed span.
caller_ranges=[]
for start,end,label in [(0x18013D187,0x18013D197,'R15 field initialization'),(0x18013D23F,0x18013D247,'helper call with R15'),(0x18013D424,0x18013D438,'later loads from R15 fields')]:
    off,raw=v.bytes_va(start,end-start)
    caller_ranges.append({'label':label,'start_va':hex(start),'end_va_exclusive':hex(end),'file_offset':hex(off),'length_bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest(),'bytes_hex':raw.hex()})
# Bind saved artifacts by hash; reuse, do not mutate them.
review=ROOT/'reconstruction/root-luna-high-research-20261012/independent-review/STITCHING-CHECKS.json'
saved_asm=ROOT/'reconstruction/root-luna-high-research-20261012/independent-review/stitching-caller.objdump.txt'
correction=ROOT/'reconstruction/root-luna-high-research-20261012/stitching/correction-01'
artifacts={}
for path in [review,saved_asm,correction/'REPORT.md',correction/'MANIFEST.json',correction/'SEAL.json',Path(__file__).with_name('helper.objdump.txt')]:
    key=str(path.relative_to(ROOT)) if path.is_relative_to(ROOT) else path.name
    artifacts[key]={'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'size_bytes':path.stat().st_size}
if artifacts[str(saved_asm.relative_to(ROOT))]['sha256']!='e2bb81db6589143ef68d36d68719f985199169cfb03df4300b32e5b4ff6c6ff3': raise ValueError('saved caller disassembly pin mismatch')
if artifacts[str((correction/'MANIFEST.json').relative_to(ROOT))]['sha256']!='c7743cbc0691959589b6ae2ec84042e88fbd8cca784ebc34bda4094a281a64b9': raise ValueError('correction packet manifest pin mismatch')
caller_asm=saved_asm.read_text(encoding='utf-8').splitlines()
r15_mentions=[line for line in caller_asm if '0x24(%r15)' in line or '0x28(%r15)' in line]
r15_stores=[line for line in r15_mentions if ('0x24(%r15)' in line or '0x28(%r15)' in line) and '$0x780,' in line]
if len(r15_stores)!=2 or not any('18013d187:' in line and '$0x780,0x24(%r15)' in line for line in r15_stores) or not any('18013d18f:' in line and '$0x780,0x28(%r15)' in line for line in r15_stores): raise ValueError('saved caller disassembly does not show exactly the two expected direct stores')
if len(r15_mentions)!=14: raise ValueError(f'unexpected count of saved caller R15 field mentions: {len(r15_mentions)}')
if '0x24(%rbx)' in helper_disasm or '0x28(%rbx)' in helper_disasm: raise ValueError('helper assembly has direct access to R15 source offsets through RBX base')
result={
 'format':'static original PE byte witnesses; no image loading or vendor execution',
 'created_utc':datetime.now(timezone.utc).isoformat(timespec='seconds').replace('+00:00','Z'),
 'source_checkout':{'repository':str(CHECKOUT),'branch':repo_branch,'head':repo_head,'origin_main':repo_main,'dirty':repo_dirty,'producer_plan_path':'docs/tasks/stitching-stereo-pair-producer.md'},
 'sources':pins,
 'eis_get_stereo_pair_export':{'decorated_name_ascii':EIS_NAME.decode('ascii'),'ordinal':eis_export['ordinal'],'rva':hex(eis_export['rva']),'va':hex(eis.base+eis_export['rva']),'section':export_section,'raw_file_offset':None,'raw_body_bytes_available':False,'finding':'Export metadata resolves the function entry to RVA 0x1474 in .text; .text has VirtualSize 0x2fc4e and RawDataSize 0, so this original PE contains no raw bytes for the export body.'},
 'vince_editor_import':import_rows[0],
 'caller_landmarks':landmark_rows,
 'saved_caller_asm_field_scan':{'mention_count':len(r15_mentions),'direct_stores':r15_stores,'interpretation':'The hash-pinned saved caller disassembly shows exactly two direct stores to these offsets; other mentions are loads.'},
 'caller_continuous_ranges':caller_ranges,
 'helper':{'va':hex(v.base+0x137740),'runtime_function_record':records[0],'file_offset':hex(helper_off),'length_bytes':len(helper_bytes),'sha256':hashlib.sha256(helper_bytes).hexdigest(),'bytes_hex':helper_hex,'observation':'Complete .pdata-bounded helper body has direct object accesses at offsets +0x6a8, +0x810, +0x814, +0x800, +0x808; no direct access at +0x24 or +0x28. Its nested callees are not independently proven side-effect-free.'},
 'saved_evidence':artifacts,
 'checks':{'source_hashes_match':True,'exact_export_found_once':True,'export_has_no_raw_section_backing':True,'exact_import_found_once_at_iat_0x180670988':True,'caller_landmarks_match':True,'helper_bounds_match_pdata':True,'prior_packet_pins_match':True}
}
OUT.write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'result':'PASS','output':str(OUT),'eis_export':result['eis_get_stereo_pair_export'],'import':result['vince_editor_import'],'helper_range':result['helper']['runtime_function_record'],'landmarks':len(landmark_rows),'caller_ranges':len(caller_ranges)},indent=2))
