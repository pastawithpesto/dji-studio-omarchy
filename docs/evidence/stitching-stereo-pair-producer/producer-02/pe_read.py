import hashlib,struct
from pathlib import Path
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
