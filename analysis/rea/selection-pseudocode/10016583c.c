/* Ghidra 12.1.4, arm64, -noanalysis; method address 0x10016583c */

/* WARNING: Globals starting with '_' overlap smaller symbols at the same address */

void selection_method_10016583c(undefined8 param_1)

{
  undefined8 uVar1;
  code *pcVar2;
  long lVar3;
  undefined *puVar4;
  undefined *puVar5;
  long lVar6;
  long lVar7;
  long extraout_x8;
  long extraout_x8_00;
  long extraout_x8_01;
  long lVar8;
  long extraout_x8_02;
  long extraout_x8_03;
  long extraout_x12;
  long unaff_x20;
  long lVar9;
  long lVar10;
  long lVar11;
  long lVar12;
  long lStack_160;
  long lStack_158;
  long lStack_150;
  long lStack_148;
  long lStack_140;
  undefined8 uStack_138;
  undefined8 uStack_128;
  undefined8 uStack_120;
  ulong uStack_118;
  undefined8 uStack_110;
  undefined8 uStack_108;
  undefined8 uStack_100;
  undefined8 uStack_f8;
  undefined8 uStack_f0;
  undefined8 uStack_e8;
  undefined8 uStack_d0;
  undefined8 uStack_c8;
  undefined8 uStack_c0;
  undefined8 uStack_b8;
  undefined8 uStack_b0;
  undefined8 uStack_a8;
  undefined8 uStack_a0;
  undefined8 uStack_98;
  undefined8 uStack_90;
  
  lVar3 = 0;
  uStack_138 = param_1;
  func_0x000100162184();
  lStack_160 = lVar3;
  (*(code *)PTR____chkstk_darwin_100a82610)(*(undefined8 *)(*(long *)(lVar3 + -8) + 0x40));
  lVar9 = (long)&lStack_160 - (extraout_x8 + 0xfU & 0xfffffffffffffff0);
  lVar3 = 0x100b13218;
  lStack_158 = lVar9;
  func_0x000100003338(0x100b13218,&UNK_100943740);
  (*(code *)PTR____chkstk_darwin_100a82610)
            (*(long *)(*(long *)(lVar3 + -8) + 0x40) + 0xfU & 0xfffffffffffffff0);
  lVar9 = lVar9 - extraout_x8_00;
  lVar3 = 0;
  func_0x0001001613c8();
  lStack_148 = *(long *)(lVar3 + -8);
  lStack_140 = lVar3;
  (*(code *)PTR____chkstk_darwin_100a82610)(*(undefined8 *)(lStack_148 + 0x40));
  lVar8 = lVar9 - (extraout_x8_01 + 0xfU & 0xfffffffffffffff0);
  lVar3 = 0x100b13230;
  lStack_150 = lVar8;
  func_0x000100003338(0x100b13230,&UNK_100943a00);
  (*(code *)PTR____chkstk_darwin_100a82610)(*(undefined8 *)(*(long *)(lVar3 + -8) + 0x40));
  lVar8 = lVar8 - (extraout_x8_02 + 0xfU & 0xfffffffffffffff0);
  (*(code *)PTR____chkstk_darwin_100a82610)();
  lVar12 = lVar8 - extraout_x12;
  lVar3 = 0;
  __s10Foundation9IndexPathVMa();
  lVar11 = *(long *)(lVar3 + -8);
  (*(code *)PTR____chkstk_darwin_100a82610)(*(undefined8 *)(lVar11 + 0x40));
  lVar10 = lVar12 - (extraout_x8_03 + 0xfU & 0xfffffffffffffff0);
  if (lRam0000000100b06ab0 != -1) {
    _swift_once(0x100b06ab0,&DAT_1001c5bf4);
  }
  uVar1 = uRam0000000100c0efc8;
  puVar4 = &UNK_1009436b8;
  _swift_getKeyPath(&UNK_1009436b8);
  puVar5 = &UNK_1009436e0;
  _swift_getKeyPath(&UNK_1009436e0);
  __s7Combine9PublishedV18_enclosingInstance7wrapped7storagexqd___s24ReferenceWritableKeyPathCyqd__xGAHyqd__ACyxGGtcRld__CluigZ
            (&uStack_128,uVar1,puVar4,puVar5);
  _swift_release(puVar4);
  _swift_release(puVar5);
  uStack_98 = uStack_f0;
  uStack_a0 = uStack_f8;
  uStack_90 = uStack_e8;
  uStack_c8 = uStack_120;
  uStack_d0 = uStack_128;
  uStack_b8 = uStack_110;
  uStack_c0 = uStack_118;
  uStack_a8 = uStack_100;
  uStack_b0 = uStack_108;
  func_0x000100033c58(&uStack_d0);
  if ((uStack_c0._3_1_ == '\x02') || ((uStack_c0 & 0x1000000) != 0)) {
    lVar6 = *(long *)(unaff_x20 + _DAT_100b131b8);
    if (lVar6 == 0) {
                    /* WARNING: Does not return */
      pcVar2 = (code *)SoftwareBreakpoint(1,0x100165cc4);
      (*pcVar2)();
    }
    _objc_retain();
    _objc_msgSend(uStack_138,PTR_s_locationInWindow_100af9ae8);
    _objc_msgSend(lVar6,PTR_s_convertPoint_fromView__100af9af0,0);
    lVar7 = lVar6;
    _objc_msgSend(lVar6,PTR_s_indexPathForItemAtPoint__100af9c60);
    _objc_retainAutoreleasedReturnValue();
    if (lVar7 != 0) {
      __s10Foundation9IndexPathV36_unconditionallyBridgeFromObjectiveCyACSo07NSIndexC0CSgFZ(lVar8);
      _objc_release(lVar7);
    }
    (**(code **)(lVar11 + 0x38))(lVar8,lVar7 == 0,1,lVar3);
    func_0x000100167168(lVar8,lVar12);
    _objc_release(lVar6);
    lVar8 = lVar12;
    (**(code **)(lVar11 + 0x30))(lVar12,1,lVar3);
    if ((int)lVar8 == 1) {
      func_0x000100005828(lVar12,0x100b13230,&UNK_100943a00);
    }
    else {
      (**(code **)(lVar11 + 0x20))(lVar10,lVar12,lVar3);
      lVar8 = *(long *)(unaff_x20 + _DAT_100b131c0);
      if (lVar8 == 0) {
                    /* WARNING: Does not return */
        pcVar2 = (code *)SoftwareBreakpoint(1,0x100165cc8);
        (*pcVar2)();
      }
      _objc_retain();
      __s6AppKit34NSCollectionViewDiffableDataSourceC14itemIdentifier3forq_Sg10Foundation9IndexPathV_tFTj
                (lVar9,lVar10);
      _objc_release(lVar8);
      lVar12 = lVar9;
      (**(code **)(lStack_148 + 0x30))(lVar9,1,lStack_140);
      lVar8 = lStack_150;
      if ((int)lVar12 == 1) {
        (**(code **)(lVar11 + 8))(lVar10,lVar3);
        func_0x000100005828(lVar9,0x100b13218,&UNK_100943740);
      }
      else {
        func_0x000100150b74(lVar9,lStack_150);
        lVar9 = unaff_x20 + _DAT_100b13198;
        _swift_weakLoadStrong();
        lVar12 = lStack_158;
        if (lVar9 != 0) {
          _swift_storeEnumTagMultiPayload(lStack_158,lStack_160,7);
          func_0x0001000dcc18(lVar8,lVar12);
          _swift_release(lVar9);
          func_0x000100005868(lVar12,&SUB_100162184);
        }
        func_0x000100005868(lVar8,&SUB_1001613c8);
        (**(code **)(lVar11 + 8))(lVar10,lVar3);
      }
    }
  }
  return;
}

