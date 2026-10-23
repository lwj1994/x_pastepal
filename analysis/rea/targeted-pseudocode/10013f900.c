/* Ghidra 12.1.4, arm64, -noanalysis; method address 0x10013f900 */

undefined8 clipboard_method_10013f900(ulong param_1)

{
  code *pcVar1;
  undefined *puVar2;
  undefined *puVar3;
  ulong uVar4;
  ulong uVar5;
  undefined8 uVar6;
  ulong uVar7;
  undefined8 *puVar8;
  undefined8 *puVar9;
  undefined8 **ppuVar10;
  ulong uVar11;
  ulong uVar12;
  ulong uVar13;
  long lVar14;
  long lVar15;
  undefined1 auStack_150 [16];
  undefined8 **ppuStack_140;
  ulong uStack_130;
  ulong uStack_128;
  undefined8 *puStack_118;
  undefined8 uStack_110;
  undefined8 uStack_108;
  undefined8 uStack_100;
  undefined8 uStack_f8;
  undefined8 uStack_f0;
  undefined8 uStack_e8;
  undefined8 uStack_e0;
  undefined8 uStack_d8;
  undefined5 uStack_d0;
  undefined8 *puStack_c0;
  undefined8 uStack_b8;
  undefined8 uStack_b0;
  undefined8 uStack_a8;
  undefined8 uStack_a0;
  undefined8 uStack_98;
  undefined8 uStack_90;
  undefined8 uStack_88;
  undefined8 uStack_80;
  char cStack_78;
  char cStack_77;
  char cStack_76;
  undefined2 uStack_75;
  
  if (lRam0000000100b06ab0 != -1) {
    _swift_once(0x100b06ab0,&DAT_1001c5bf4);
  }
  uVar6 = uRam0000000100c0efc8;
  puVar2 = &UNK_100942cc0;
  _swift_getKeyPath(&UNK_100942cc0);
  puVar3 = &UNK_100942ce8;
  _swift_getKeyPath(&UNK_100942ce8);
  __s7Combine9PublishedV18_enclosingInstance7wrapped7storagexqd___s24ReferenceWritableKeyPathCyqd__xGAHyqd__ACyxGGtcRld__CluigZ
            (&puStack_118,uVar6,puVar2,puVar3);
  _swift_release(puVar2);
  _swift_release(puVar3);
  uStack_98 = uStack_f0;
  uStack_a0 = uStack_f8;
  uStack_88 = uStack_e0;
  uStack_90 = uStack_e8;
  cStack_78 = (char)uStack_d0;
  cStack_77 = (char)((uint5)uStack_d0 >> 8);
  cStack_76 = (char)((uint5)uStack_d0 >> 0x10);
  uStack_75 = (undefined2)((uint5)uStack_d0 >> 0x18);
  uStack_80 = uStack_d8;
  uStack_b8 = uStack_110;
  puStack_c0 = puStack_118;
  uStack_a8 = uStack_100;
  uStack_b0 = uStack_108;
  if (param_1 >> 0x3e == 0) {
    uVar12 = *(ulong *)((param_1 & 0xffffffffffffff8) + 0x10);
    puVar8 = (undefined8 *)PTR___swiftEmptyArrayStorage_100a866b8;
  }
  else {
    uVar12 = param_1 & 0xffffffffffffff8;
    if ((long)param_1 < 0) {
      uVar12 = param_1;
    }
    __ss18_CocoaArrayWrapperV8endIndexSivg();
    puVar8 = (undefined8 *)PTR___swiftEmptyArrayStorage_100a866b8;
  }
  PTR___swiftEmptyArrayStorage_100a866b8 = (undefined *)puVar8;
  if (uVar12 != 0) {
    uVar13 = 0;
    uStack_128 = param_1 & 0xc000000000000001;
    uStack_130 = param_1 & 0xffffffffffffff8;
    puVar9 = puVar8;
    do {
      if (uStack_128 == 0) {
        if (*(ulong *)(uStack_130 + 0x10) <= uVar13) {
                    /* WARNING: Does not return */
          pcVar1 = (code *)SoftwareBreakpoint(1,0x10013fb44);
          (*pcVar1)();
        }
        uVar4 = *(ulong *)(param_1 + uVar13 * 8 + 0x20);
        _objc_retain();
      }
      else {
        uVar4 = uVar13;
        func_0x000100187598(uVar13,param_1);
      }
      if (SCARRY8(uVar13,1)) {
                    /* WARNING: Does not return */
        pcVar1 = (code *)SoftwareBreakpoint(1,0x10013fb40);
        (*pcVar1)();
      }
      uVar11 = uVar13 + 1;
      _objc_retain();
      uVar5 = uVar4;
      _objc_msgSend();
      _objc_retainAutoreleasedReturnValue();
      uVar6 = 0;
      func_0x000100003754(0);
      uVar7 = uVar5;
      __sSa10FoundationE36_unconditionallyBridgeFromObjectiveCySayxGSo7NSArrayCSgFZ(uVar5,uVar6);
      _objc_release(uVar4);
      _objc_release(uVar4);
      _objc_release(uVar5);
      lVar14 = *(long *)(uVar7 + 0x10);
      lVar15 = puVar9[2];
      if (SCARRY8(lVar15,lVar14)) {
                    /* WARNING: Does not return */
        pcVar1 = (code *)SoftwareBreakpoint(1,0x10013fb48);
        (*pcVar1)();
      }
      puVar8 = puVar9;
      _swift_isUniquelyReferenced_nonNull_native();
      if (((int)puVar8 == 0) || ((long)((ulong)puVar9[3] >> 1) < lVar15 + lVar14)) {
        func_0x000100186898();
        puVar9 = puVar8;
        if (*(long *)(uVar7 + 0x10) == 0) goto LAB_10013f9e8;
LAB_10013fadc:
        if ((long)(((ulong)puVar8[3] >> 1) - puVar8[2]) < lVar14) {
                    /* WARNING: Does not return */
          pcVar1 = (code *)SoftwareBreakpoint(1,0x10013fb50);
          (*pcVar1)();
        }
        _swift_arrayInitWithCopy(puVar8 + puVar8[2] + 4,uVar7 + 0x20,lVar14,uVar6);
        _swift_bridgeObjectRelease(uVar7);
        if (lVar14 != 0) {
          if (SCARRY8(puVar8[2],lVar14)) {
                    /* WARNING: Does not return */
            pcVar1 = (code *)SoftwareBreakpoint(1,0x10013fb54);
            (*pcVar1)();
          }
          puVar8[2] = puVar8[2] + lVar14;
        }
      }
      else {
        puVar8 = puVar9;
        if (*(long *)(uVar7 + 0x10) != 0) goto LAB_10013fadc;
LAB_10013f9e8:
        _swift_bridgeObjectRelease(uVar7);
        puVar8 = puVar9;
        if (lVar14 != 0) {
                    /* WARNING: Does not return */
          pcVar1 = (code *)SoftwareBreakpoint(1,0x10013fb4c);
          (*pcVar1)();
        }
      }
      uVar13 = uVar13 + 1;
      puVar9 = puVar8;
    } while (uVar11 != uVar12);
  }
  puVar9 = puVar8;
  func_0x00010013f674();
  if (((ulong)puVar9 & 1) == 0) {
    if (cStack_78 == '\x01') {
      func_0x00010037bf44();
      puVar9 = (undefined8 *)*puVar9;
      puStack_118 = puVar9;
      (*(code *)PTR____chkstk_darwin_100a82610)();
      ppuStack_140 = &puStack_118;
      _objc_retain();
      uVar12 = 0;
      func_0x0001001abb68(&DAT_10014028c,auStack_150,puVar8);
      _objc_release();
      if ((uVar12 & 1) != 0) goto LAB_10013fb98;
    }
    if (cStack_77 == '\x01') {
      func_0x00010037bfd4();
      puVar9 = (undefined8 *)*puVar9;
      puStack_118 = puVar9;
      (*(code *)PTR____chkstk_darwin_100a82610)();
      ppuStack_140 = &puStack_118;
      _objc_retain();
      uVar12 = 0;
      func_0x0001001abb68(&DAT_10014028c,auStack_150,puVar8);
      _objc_release(puVar9);
      if ((uVar12 & 1) != 0) goto LAB_10013fb98;
    }
    ppuVar10 = &puStack_c0;
    func_0x000100033c58();
    if (cStack_76 == '\x01') {
      func_0x00010037c064();
      puVar9 = *ppuVar10;
      puStack_118 = puVar9;
      (*(code *)PTR____chkstk_darwin_100a82610)();
      ppuStack_140 = &puStack_118;
      _objc_retain();
      uVar12 = 0;
      func_0x0001001abb68(&DAT_100140270,auStack_150,puVar8);
      _objc_release(puVar9);
      _swift_bridgeObjectRelease(puVar8);
      if ((uVar12 & 1) != 0) {
        return 0;
      }
    }
    else {
      _swift_bridgeObjectRelease(puVar8);
    }
    uVar6 = 1;
  }
  else {
LAB_10013fb98:
    _swift_bridgeObjectRelease(puVar8);
    func_0x000100033c58(&puStack_c0);
    uVar6 = 0;
  }
  return uVar6;
}

