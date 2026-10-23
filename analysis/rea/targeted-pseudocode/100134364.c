/* Ghidra 12.1.4, arm64, -noanalysis; method address 0x100134364 */

/* WARNING: Globals starting with '_' overlap smaller symbols at the same address */

void clipboard_method_100134364(void)

{
  ulong uVar1;
  code *pcVar2;
  long lVar3;
  undefined8 uVar4;
  ulong uVar5;
  ulong uVar6;
  undefined *puVar7;
  long lVar8;
  undefined *puVar9;
  undefined **ppuVar10;
  long extraout_x8;
  long extraout_x8_00;
  long lVar11;
  long lVar12;
  long lVar13;
  ulong uVar14;
  long extraout_x12;
  long extraout_x12_00;
  long unaff_x20;
  long lVar15;
  ulong uVar16;
  ulong uVar17;
  undefined1 *puVar18;
  long lVar19;
  ulong uVar20;
  undefined1 auStack_d0 [8];
  ulong uStack_c8;
  undefined *puStack_c0;
  ulong uStack_b8;
  undefined *puStack_90;
  undefined8 uStack_88;
  undefined *puStack_80;
  undefined *puStack_78;
  undefined *puStack_70;
  undefined *puStack_68;
  
  lVar8 = 0x100b08ce0;
  func_0x000100003338(0x100b08ce0,&UNK_100933100);
  (*(code *)PTR____chkstk_darwin_100a82610)
            (*(long *)(*(long *)(lVar8 + -8) + 0x40) + 0xfU & 0xfffffffffffffff0);
  puVar18 = auStack_d0 + -extraout_x8;
  lVar8 = 0x100b08ca8;
  func_0x000100003338(0x100b08ca8,&UNK_100932700);
  (*(code *)PTR____chkstk_darwin_100a82610)
            (*(long *)(*(long *)(lVar8 + -8) + 0x40) + 0xfU & 0xfffffffffffffff0);
  lVar19 = (long)puVar18 - extraout_x8_00;
  lVar3 = 0;
  func_0x00010019b3dc();
  lVar11 = *(long *)(lVar3 + -8);
  lVar15 = *(long *)(lVar11 + 0x40);
  (*(code *)PTR____chkstk_darwin_100a82610)();
  lVar12 = lVar19 - (lVar15 + 0xfU & 0xfffffffffffffff0);
  (*(code *)PTR____chkstk_darwin_100a82610)();
  lVar13 = lVar12 - extraout_x12;
  (*(code *)PTR____chkstk_darwin_100a82610)();
  uVar14 = lVar13 - extraout_x12_00;
  uVar17 = *(ulong *)(unaff_x20 + 0x10);
  lVar8 = *(long *)(unaff_x20 + 0x18);
  uVar16 = *(ulong *)(lVar8 + 0x10);
  uVar20 = uVar17;
  _objc_msgSend(uVar17,PTR_s_changeCount_100af9890);
  if (uVar16 == 0xffffffffffffffff) {
    *(ulong *)(lVar8 + 0x10) = uVar20;
    return;
  }
  if (uVar16 == uVar20) {
    return;
  }
  uVar20 = uVar17;
  _objc_msgSend(uVar17,PTR_s_changeCount_100af9890);
  *(ulong *)(lVar8 + 0x10) = uVar20;
  func_0x0001001cd30c(0);
  _swift_initStaticObject();
  func_0x0001001ccc54(lVar19);
  lVar8 = lVar19;
  (**(code **)(lVar11 + 0x30))(lVar19,1,lVar3);
  if ((int)lVar8 == 1) {
    func_0x000100005828(lVar19,0x100b08ca8,&UNK_100932700);
    return;
  }
  func_0x0001000058a4(lVar19,uVar14,&SUB_10019b3dc);
  uVar20 = uVar14;
  func_0x00010013f3d8();
  if ((uVar20 & 1) == 0) goto LAB_100134a6c;
  uVar20 = uVar17;
  _objc_msgSend(uVar17,PTR_s_pasteboardItems_100af9898);
  _objc_retainAutoreleasedReturnValue();
  if (uVar20 == 0) goto LAB_100134a6c;
  uVar4 = 0;
  func_0x0001001355f8(0);
  uVar16 = uVar20;
  __sSa10FoundationE36_unconditionallyBridgeFromObjectiveCySayxGSo7NSArrayCSgFZ(uVar20,uVar4);
  _objc_release(uVar20);
  if (uVar16 >> 0x3e == 0) {
    uVar20 = *(ulong *)((uVar16 & 0xffffffffffffff8) + 0x10);
  }
  else {
    uVar20 = uVar16 & 0xffffffffffffff8;
    if ((long)uVar16 < 0) {
      uVar20 = uVar16;
    }
    __ss18_CocoaArrayWrapperV8endIndexSivg();
  }
  _swift_bridgeObjectRelease(uVar16);
  if (uVar20 == 0) goto LAB_100134a6c;
  _objc_msgSend(uVar17,PTR_s_pasteboardItems_100af9898);
  _objc_retainAutoreleasedReturnValue();
  if (uVar17 == 0) goto LAB_100134a6c;
  uVar20 = uVar17;
  __sSa10FoundationE36_unconditionallyBridgeFromObjectiveCySayxGSo7NSArrayCSgFZ();
  _objc_release(uVar17);
  uVar17 = uVar20;
  func_0x00010013f900();
  if ((uVar17 & 1) == 0) {
    func_0x000100005868(uVar14,&SUB_10019b3dc);
    _swift_bridgeObjectRelease(uVar20);
    return;
  }
  uStack_c8 = lVar13;
  if (uVar20 >> 0x3e == 0) {
    uVar17 = *(ulong *)((uVar20 & 0xffffffffffffff8) + 0x10);
    if (uVar17 == 0) goto LAB_100134758;
LAB_1001345f8:
    uStack_b8 = uVar20 & 0xc000000000000001;
    puStack_c0 = PTR___swiftEmptyArrayStorage_100a866b8;
    uVar16 = 0;
    do {
      while( true ) {
        if (uStack_b8 == 0) {
          if (*(ulong *)((uVar20 & 0xffffffffffffff8) + 0x10) <= uVar16) {
                    /* WARNING: Does not return */
            pcVar2 = (code *)SoftwareBreakpoint(1,0x100134720);
            (*pcVar2)();
          }
          uVar5 = *(ulong *)(uVar20 + uVar16 * 8 + 0x20);
          _objc_retain();
        }
        else {
          uVar5 = uVar16;
          func_0x000100187598(uVar16,uVar20);
        }
        uVar1 = uVar16 + 1;
        if (SCARRY8(uVar16,1)) {
                    /* WARNING: Does not return */
          pcVar2 = (code *)SoftwareBreakpoint(1,0x10013471c);
          (*pcVar2)();
        }
        uVar6 = uVar5;
        func_0x00010013fd5c();
        puVar9 = puStack_c0;
        if ((uVar6 & 1) != 0) break;
        _objc_release(uVar5);
        uVar16 = uVar16 + 1;
        if (uVar1 == uVar17) goto LAB_100134764;
      }
      puVar7 = puStack_c0;
      _swift_isUniquelyReferenced_nonNull_native();
      puStack_90 = puVar9;
      if (((ulong)puVar7 & 1) == 0) {
        func_0x0001001881c4(0,*(long *)(puVar9 + 0x10) + 1,1);
      }
      uVar16 = *(ulong *)(puStack_90 + 0x10);
      puStack_c0 = (undefined *)(uVar16 + 1);
      if (*(ulong *)(puStack_90 + 0x18) >> 1 <= uVar16) {
        func_0x0001001881c4(1 < *(ulong *)(puStack_90 + 0x18),puStack_c0,1);
      }
      *(undefined **)(puStack_90 + 0x10) = puStack_c0;
      *(ulong *)(puStack_90 + uVar16 * 8 + 0x20) = uVar5;
      uVar16 = uVar1;
      puStack_c0 = puStack_90;
    } while (uVar1 != uVar17);
  }
  else {
    uVar17 = uVar20 & 0xffffffffffffff8;
    if ((long)uVar20 < 0) {
      uVar17 = uVar20;
    }
    __ss18_CocoaArrayWrapperV8endIndexSivg();
    if (uVar17 != 0) goto LAB_1001345f8;
LAB_100134758:
    puStack_c0 = PTR___swiftEmptyArrayStorage_100a866b8;
  }
LAB_100134764:
  _swift_bridgeObjectRelease(uVar20);
  if (lRam0000000100b068c8 != -1) {
    _swift_once(0x100b068c8,&DAT_10008e4cc);
  }
  puVar9 = puStack_c0;
  if (*(char *)(lRam0000000100c0ebc0 + _DAT_100c0ebc8) == '\x01') {
    func_0x000100090814(puStack_c0);
    _swift_release(puVar9);
  }
  else {
    if (lRam0000000100b06910 != -1) {
      _swift_once(0x100b06910,&DAT_1000c7de4);
    }
    puVar9 = puStack_c0;
    puVar7 = puStack_c0;
    func_0x000100135ea4(puStack_c0);
    _swift_release(puVar9);
    lVar8 = 0;
    func_0x0001001a4330();
    (**(code **)(*(long *)(lVar8 + -8) + 0x38))(puVar18,1,1,lVar8);
    func_0x000100134b00(puVar7,puVar18,0,0,uVar14);
    _swift_bridgeObjectRelease(puVar7);
    func_0x000100005828(puVar18,0x100b08ce0,&UNK_100933100);
    if (lRam0000000100b069a8 != -1) {
      _swift_once(0x100b069a8,&DAT_10017b4c8);
    }
    uVar17 = uStack_c8;
    uVar4 = uRam0000000100c0ed40;
    if (lRam0000000100b069b0 != -1) {
      _swift_once(0x100b069b0,&DAT_10017c9a8);
    }
    lVar8 = *(long *)(lRam0000000100c0ed48 + 0x18);
    if (lVar8 != 0) {
      puVar9 = &UNK_100942ae8;
      _swift_getKeyPath(&UNK_100942ae8);
      puVar7 = &UNK_100942b10;
      _swift_getKeyPath(&UNK_100942b10);
      _objc_retain();
      __s7Combine9PublishedV18_enclosingInstance7wrapped7storagexqd___s24ReferenceWritableKeyPathCyqd__xGAHyqd__ACyxGGtcRld__CluigZ
                (&puStack_90,uVar4,puVar9,puVar7);
      _swift_release(puVar9);
      _swift_release(puVar7);
      puVar9 = puStack_90;
      uVar20 = 0;
      uVar16 = *(ulong *)(puStack_90 + 0x10);
      do {
        if (uVar16 == uVar20) {
          _swift_bridgeObjectRelease(puVar9);
          puVar9 = &UNK_100a95f68;
          _swift_allocObject(&UNK_100a95f68,0x18,7);
          _swift_unknownObjectWeakInit(puVar9 + 0x10,lVar8);
          func_0x0001000057e4(uVar14,lVar12,&SUB_10019b3dc);
          uVar17 = (ulong)*(byte *)(lVar11 + 0x50);
          uVar20 = uVar17 + 0x18 & (uVar17 ^ 0xffffffffffffffff);
          puVar7 = &UNK_100a95f90;
          _swift_allocObject(&UNK_100a95f90,uVar20 + lVar15,uVar17 | 7);
          *(undefined **)(puVar7 + 0x10) = puVar9;
          func_0x0001000058a4(lVar12,puVar7 + uVar20,&SUB_10019b3dc);
          puStack_70 = &DAT_100135710;
          puStack_90 = PTR___NSConcreteStackBlock_100a82608;
          uStack_88 = _UNK_100933cb0;
          puStack_80 = &DAT_1001899ec;
          puStack_78 = &UNK_100a95fa8;
          ppuVar10 = &puStack_90;
          puStack_68 = puVar7;
          __Block_copy(ppuVar10);
          _swift_release(puStack_68);
          _objc_msgSend(lVar8,PTR_s_performBlock__100af92e0,ppuVar10);
          __Block_release(ppuVar10);
          goto LAB_100134a64;
        }
        if (*(ulong *)(puVar9 + 0x10) <= uVar20) {
                    /* WARNING: Does not return */
          pcVar2 = (code *)SoftwareBreakpoint(1,0x100134aa0);
          (*pcVar2)();
        }
        func_0x0001000057e4(puVar9 + *(long *)(lVar11 + 0x48) * uVar20 +
                                     ((ulong)*(byte *)(lVar11 + 0x50) + 0x20 &
                                     ((ulong)*(byte *)(lVar11 + 0x50) ^ 0xffffffffffffffff)),uVar17,
                            &SUB_10019b3dc);
        uVar5 = *(ulong *)(uVar17 + 8);
        if (uVar5 == *(ulong *)(uVar14 + 8) && *(long *)(uVar17 + 0x10) == *(long *)(uVar14 + 0x10))
        {
          func_0x000100005868(uVar17,&SUB_10019b3dc);
          break;
        }
        uVar20 = uVar20 + 1;
        __ss27_stringCompareWithSmolCheck__9expectingSbs11_StringGutsV_ADs01_G16ComparisonResultOtF
                  ();
        func_0x000100005868(uVar17,&SUB_10019b3dc);
      } while ((uVar5 & 1) == 0);
      _swift_bridgeObjectRelease(puVar9);
LAB_100134a64:
      _objc_release(lVar8);
    }
  }
LAB_100134a6c:
  func_0x000100005868(uVar14,&SUB_10019b3dc);
  return;
}

