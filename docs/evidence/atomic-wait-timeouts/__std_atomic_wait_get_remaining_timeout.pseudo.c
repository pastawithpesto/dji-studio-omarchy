
ulonglong __std_atomic_wait_get_remaining_timeout(ulonglong param_1)

{
  ULONGLONG UVar1;
  ulonglong uVar2;
  
                    /* 0x15f0  12  __std_atomic_wait_get_remaining_timeout */
  if (param_1 == 0xffffffffffffffff) {
    uVar2 = 0xffffffff;
  }
  else {
    UVar1 = GetTickCount64();
    if (UVar1 < param_1) {
      uVar2 = 864000000;
      if (param_1 - UVar1 < 0x337f9801) {
        uVar2 = param_1 - UVar1 & 0xffffffff;
      }
    }
    else {
      uVar2 = 0;
    }
  }
  return uVar2;
}

