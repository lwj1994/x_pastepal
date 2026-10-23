/* Ghidra 12.1.4, arm64, -noanalysis; method address 0x10013fd5c */

undefined8 clipboard_method_10013fd5c(undefined8 ****param_1)

{
  undefined8 uVar1;
  long lVar2;
  code *pcVar3;
  long lVar4;
  undefined *puVar5;
  undefined *puVar6;
  undefined8 ****ppppuVar7;
  undefined8 ****ppppuVar8;
  undefined8 ****ppppuVar9;
  undefined8 ***pppuVar10;
  undefined8 ****ppppuVar11;
  long extraout_x8;
  long extraout_x8_00;
  long extraout_x8_01;
  undefined8 ****ppppuVar12;
  undefined8 ***pppuVar13;
  undefined8 ***pppuVar14;
  long lVar15;
  long lVar16;
  long lVar17;
  ulong uVar18;
  undefined8 ***pppuVar19;
  ulong uVar20;
  undefined8 ***apppuStack_160 [2];
  long lStack_150;
  long lStack_148;
  long lStack_140;
  undefined8 ***pppuStack_138;
  undefined8 **ppuStack_130;
  undefined8 ***pppuStack_128;
  undefined8 **ppuStack_120;
  undefined8 uStack_118;
  undefined8 uStack_110;
  undefined8 uStack_108;
  undefined8 uStack_100;
  undefined8 uStack_f8;
  undefined8 uStack_f0;
  long lStack_e8;
  undefined8 ***pppuStack_d0;
  undefined8 **ppuStack_c8;
  undefined8 uStack_c0;
  undefined8 uStack_b8;
  undefined8 uStack_b0;
  undefined8 uStack_a8;
  undefined8 uStack_a0;
  undefined8 uStack_98;
  long lStack_90;
  
  lVar4 = 0;
  func_0x0001001c1788();
  lVar16 = *(long *)(lVar4 + -8);
  (*(code *)PTR____chkstk_darwin_100a82610)(*(undefined8 *)(lVar16 + 0x40));
  pppuVar14 = (undefined8 ***)((long)apppuStack_160 - (extraout_x8 + 0xfU & 0xfffffffffffffff0));
  lVar4 = 0x100b09108;
  func_0x000100003338(0x100b09108,&UNK_100933e30);
  (*(code *)PTR____chkstk_darwin_100a82610)
            (*(long *)(*(long *)(lVar4 + -8) + 0x40) + 0xfU & 0xfffffffffffffff0);
  pppuVar19 = (undefined8 ***)((long)pppuVar14 - extraout_x8_00);
  lVar4 = 0;
  __s10Foundation3URLVMa();
  lVar17 = *(long *)(lVar4 + -8);
  (*(code *)PTR____chkstk_darwin_100a82610)(*(undefined8 *)(lVar17 + 0x40));
  lStack_140 = (long)pppuVar19 - (extraout_x8_01 + 0xfU & 0xfffffffffffffff0);
  if (lRam0000000100b06ab0 != -1) {
    _swift_once(0x100b06ab0,&DAT_1001c5bf4);
  }
  uVar1 = uRam0000000100c0efc8;
  puVar5 = &UNK_100942cc0;
  _swift_getKeyPath(&UNK_100942cc0);
  puVar6 = &UNK_100942ce8;
  _swift_getKeyPath();
  __s7Combine9PublishedV18_enclosingInstance7wrapped7storagexqd___s24ReferenceWritableKeyPathCyqd__xGAHyqd__ACyxGGtcRld__CluigZ
            (&pppuStack_128,uVar1,puVar5,puVar6);
  _swift_release(puVar5);
  _swift_release();
  uStack_a8 = uStack_100;
  uStack_b0 = uStack_108;
  uStack_98 = uStack_f0;
  uStack_a0 = uStack_f8;
  lStack_90 = lStack_e8;
  ppuStack_c8 = ppuStack_120;
  pppuStack_d0 = pppuStack_128;
  uStack_b8 = uStack_110;
  uStack_c0 = uStack_118;
  func_0x0001001b943c();
  lVar15 = *(long *)(puVar6 + 0x10);
  _swift_bridgeObjectRelease();
  if (lVar15 != 0) {
    ppppuVar11 = param_1;
    pppuVar10 = (undefined8 ***)PTR_s_stringForType__100af98a0;
    _objc_msgSend(param_1,PTR_s_stringForType__100af98a0,
                  *(undefined8 *)PTR__NSPasteboardTypeString_100a82a90);
    _objc_retainAutoreleasedReturnValue();
    if (ppppuVar11 != (undefined8 ****)0x0) {
      ppppuVar7 = ppppuVar11;
      apppuStack_160[0] = pppuVar19;
      apppuStack_160[1] = param_1;
      lStack_150 = lVar17;
      lStack_148 = lVar4;
      __sSS10FoundationE36_unconditionallyBridgeFromObjectiveCySSSo8NSStringCSgFZ();
      _objc_release();
      func_0x0001001b943c();
      puVar5 = PTR___sSSN_100a856c8;
      pppuVar13 = ppppuVar11[2];
      pppuVar19 = (undefined8 ***)0xffffffffffffffff;
      ppppuVar8 = ppppuVar11;
      ppppuVar12 = ppppuVar11 + 5;
      while ((long)pppuVar19 - (long)pppuVar13 != -1) {
        pppuVar19 = (undefined8 ***)((long)pppuVar19 + 1);
        if (ppppuVar11[2] <= pppuVar19) {
                    /* WARNING: Does not return */
          pcVar3 = (code *)SoftwareBreakpoint(1,0x1001401cc);
          (*pcVar3)();
        }
        pppuStack_138 = ppppuVar12[-1];
        ppuStack_130 = *ppppuVar12;
        pppuStack_128 = ppppuVar7;
        ppuStack_120 = pppuVar10;
        func_0x00010000712c();
        ppppuVar9 = &pppuStack_138;
        __sSy10FoundationE8containsySbqd__SyRd__lF(ppppuVar9,puVar5,puVar5,ppppuVar8,ppppuVar8);
        ppppuVar8 = ppppuVar9;
        ppppuVar12 = ppppuVar12 + 2;
        if (((ulong)ppppuVar9 & 1) != 0) {
          func_0x000100033c58(&pppuStack_d0);
          _swift_bridgeObjectRelease(pppuVar10);
          _swift_bridgeObjectRelease(ppppuVar11);
          return 0;
        }
      }
      _swift_bridgeObjectRelease(pppuVar10);
      _swift_bridgeObjectRelease(ppppuVar11);
      lVar4 = lStack_148;
      lVar17 = lStack_150;
      pppuVar19 = apppuStack_160[0];
    }
  }
  lVar15 = lStack_90;
  if (*(long *)(lStack_90 + 0x10) == 0) {
    func_0x000100033c58(&pppuStack_d0);
  }
  else {
    func_0x0001003a5040(pppuVar19);
    pppuVar10 = pppuVar19;
    (**(code **)(lVar17 + 0x30))(pppuVar19,1,lVar4);
    lVar2 = lStack_140;
    if ((int)pppuVar10 == 1) {
      func_0x000100033c58(&pppuStack_d0);
      func_0x000100027ba8(pppuVar19);
    }
    else {
      lStack_150 = lVar17;
      lStack_148 = lVar4;
      (**(code **)(lVar17 + 0x20))(lStack_140,pppuVar19,lVar4);
      puVar5 = PTR___sSSN_100a856c8;
      uVar18 = 0;
      uVar20 = *(ulong *)(lVar15 + 0x10);
      while (uVar20 != uVar18) {
        if (*(ulong *)(lVar15 + 0x10) <= uVar18) {
                    /* WARNING: Does not return */
          pcVar3 = (code *)SoftwareBreakpoint(1,0x1001401d0);
          (*pcVar3)();
        }
        ppppuVar11 = (undefined8 ****)
                     (lVar15 + ((ulong)*(byte *)(lVar16 + 0x50) + 0x20 &
                               ((ulong)*(byte *)(lVar16 + 0x50) ^ 0xffffffffffffffff)) +
                     *(long *)(lVar16 + 0x48) * uVar18);
        pppuVar19 = pppuVar14;
        func_0x0001001401f0();
        uVar18 = uVar18 + 1;
        __s10Foundation3URLV4pathSSvg();
        pppuVar10 = pppuVar19;
        pppuStack_128 = ppppuVar11;
        ppuStack_120 = pppuVar19;
        __s10Foundation3URLV4pathSSvg();
        pppuStack_138 = ppppuVar11;
        ppuStack_130 = pppuVar10;
        func_0x00010000712c();
        ppppuVar7 = &pppuStack_138;
        __sSy10FoundationE8containsySbqd__SyRd__lF(ppppuVar7,puVar5,puVar5,ppppuVar11,ppppuVar11);
        _swift_bridgeObjectRelease(pppuVar19);
        _swift_bridgeObjectRelease(pppuVar10);
        func_0x000100140234(pppuVar14);
        if (((ulong)ppppuVar7 & 1) != 0) {
          func_0x000100033c58(&pppuStack_d0);
          (**(code **)(lStack_150 + 8))(lVar2,lStack_148);
          return 0;
        }
      }
      func_0x000100033c58(&pppuStack_d0);
      (**(code **)(lStack_150 + 8))(lVar2,lStack_148);
    }
  }
  return 1;
}

