
longlong __std_atomic_wait_get_deadline(longlong param_1)

{
  longlong lVar1;
  ULONGLONG UVar2;
  
                    /* 0x15c0  11  __std_atomic_wait_get_deadline */
  lVar1 = -1;
  if (param_1 != -1) {
    UVar2 = GetTickCount64();
    lVar1 = UVar2 + param_1;
  }
  return lVar1;
}

