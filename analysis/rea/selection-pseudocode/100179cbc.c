/* Ghidra 12.1.4, arm64, -noanalysis; method address 0x100179cbc */

/* WARNING: Globals starting with '_' overlap smaller symbols at the same address */

void selection_method_100179cbc(long param_1)

{
  code *pcVar1;
  long lVar2;
  long lVar3;
  long lVar4;
  long lVar5;
  long extraout_x8;
  long extraout_x8_00;
  long extraout_x12;
  long unaff_x20;
  long lVar6;
  long lVar7;
  undefined1 *puVar8;
  long lVar9;
  
  _swift_getObjectType();
  lVar2 = 0x100b13230;
  func_0x000100003338(0x100b13230,&UNK_100943a00);
  (*(code *)PTR____chkstk_darwin_100a82610)(*(undefined8 *)(*(long *)(lVar2 + -8) + 0x40));
  puVar8 = &stack0xffffffffffffff90 + -(extraout_x8 + 0xfU & 0xfffffffffffffff0);
  (*(code *)PTR____chkstk_darwin_100a82610)();
  lVar6 = (long)puVar8 - extraout_x12;
  lVar3 = 0;
  __s10Foundation9IndexPathVMa();
  lVar9 = *(long *)(lVar3 + -8);
  (*(code *)PTR____chkstk_darwin_100a82610)(*(undefined8 *)(lVar9 + 0x40));
  lVar7 = lVar6 - (extraout_x8_00 + 0xfU & 0xfffffffffffffff0);
  _objc_msgSendSuper2(&stack0xffffffffffffff90,PTR_s_mouseDown__100af9ac8,param_1);
  lVar2 = param_1;
  _objc_msgSend(param_1,PTR_s_clickCount_100af9d30);
  if (lVar2 == 2) {
    lVar2 = unaff_x20 + _DAT_100b13368;
    _swift_unknownObjectWeakLoadStrong();
    if (lVar2 != 0) {
      func_0x00010016583c(param_1);
      _objc_release(lVar2);
    }
  }
  else if (lVar2 == 1) {
    lVar2 = unaff_x20 + _DAT_100b13368;
    _swift_unknownObjectWeakLoadStrong();
    if (lVar2 != 0) {
      lVar4 = *(long *)(lVar2 + _DAT_100b131b8);
      if (lVar4 == 0) {
                    /* WARNING: Does not return */
        pcVar1 = (code *)SoftwareBreakpoint(1,0x100179f54);
        (*pcVar1)();
      }
      _objc_retain();
      _objc_msgSend(param_1,PTR_s_locationInWindow_100af9ae8);
      _objc_msgSend(lVar4,PTR_s_convertPoint_fromView__100af9af0,0);
      lVar5 = lVar4;
      _objc_msgSend(lVar4,PTR_s_indexPathForItemAtPoint__100af9c60);
      _objc_retainAutoreleasedReturnValue();
      if (lVar5 != 0) {
        __s10Foundation9IndexPathV36_unconditionallyBridgeFromObjectiveCyACSo07NSIndexC0CSgFZ
                  (puVar8);
        _objc_release(lVar5);
      }
      (**(code **)(lVar9 + 0x38))(puVar8,lVar5 == 0,1,lVar3);
      func_0x000100167168(puVar8,lVar6);
      _objc_release(lVar4);
      lVar4 = lVar6;
      (**(code **)(lVar9 + 0x30))(lVar6,1,lVar3);
      if ((int)lVar4 == 1) {
        _objc_release(lVar2);
        func_0x000100005828(lVar6,0x100b13230,&UNK_100943a00);
      }
      else {
        (**(code **)(lVar9 + 0x20))(lVar7,lVar6,lVar3);
        _objc_msgSend(param_1,PTR_s_modifierFlags_100af93b0);
        if (((uint)param_1 >> 0x11 & 1) != 0) {
          func_0x000100165298(lVar7);
        }
        _objc_release(lVar2);
        (**(code **)(lVar9 + 8))(lVar7,lVar3);
      }
    }
  }
  return;
}

