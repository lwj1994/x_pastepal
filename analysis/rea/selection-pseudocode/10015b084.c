/* Ghidra 12.1.4, arm64, -noanalysis; method address 0x10015b084 */

/* WARNING: Globals starting with '_' overlap smaller symbols at the same address */

void selection_method_10015b084(undefined8 param_1)

{
  code *pcVar1;
  undefined8 uVar2;
  int iVar3;
  long lVar5;
  long unaff_x20;
  long lVar4;
  
  func_0x00010015b488();
  _objc_msgSendSuper2(&stack0xffffffffffffffb0,PTR_s_mouseDown__100af9ac8,param_1);
  lVar5 = *(long *)(unaff_x20 + _DAT_100b12de8);
  _objc_msgSend(param_1,PTR_s_locationInWindow_100af9ae8);
  _objc_msgSend(lVar5,PTR_s_convertPoint_fromView__100af9af0,0);
  lVar4 = lVar5;
  _objc_msgSend(lVar5,PTR_s_bounds_100af9a78);
  iVar3 = (int)lVar4;
  _CGRectContainsPoint();
  if (iVar3 != 0) {
    pcVar1 = *(code **)(lVar5 + _DAT_100b12f60);
    uVar2 = ((undefined8 *)(lVar5 + _DAT_100b12f60))[1];
    _swift_retain(uVar2);
    (*pcVar1)();
    _swift_release(uVar2);
  }
  return;
}

