/* REA 6.4.0 + Ghidra 12.1.4; ev_3b4b3cc59df36e81a4bf05dbe4c5d6f2d2af4ff8095319e71de5ff82bedc56cd */

/* WARNING: Function: _objc_retainAutoreleasedReturnValue replaced with injection:
   _objc_retain_fixup */
/* WARNING: Function: _objc_release replaced with injection: _objc_release_fixup */
/* WARNING: Function: _objc_retain replaced with injection: _objc_retain_fixup */

void FUN_100134364(void)

{
  ulong uVar1;
  _CocoaArrayWrapper _Var2;
  undefined8 uVar3;
  code *pcVar4;
  bool bVar5;
  long lVar6;
  ID IVar7;
  undefined *puVar8;
  undefined *puVar9;
  ulong uVar10;
  ulong uVar11;
  undefined *puVar12;
  long lVar13;
  void *aBlock;
  long extraout_x8;
  long extraout_x8_00;
  long lVar14;
  long lVar15;
  long lVar16;
  ulong uVar17;
  long extraout_x12;
  long extraout_x12_00;
  long unaff_x20;
  ID IVar18;
  ulong uVar19;
  long lVar20;
  ID IVar21;
  ulong uVar22;
  undefined1 *puVar23;
  long lVar24;
  __int64 _Var25;
  undefined1 auStack_d0 [8];
  long local_c8;
  undefined *local_c0;
  ulong local_b8;
  undefined *local_90;
  undefined8 local_88;
  code *local_80;
  undefined *puStack_78;
  code *local_70;
  undefined *local_68;
  
  puVar8 = &DAT_100b08ce0;
  FUN_100003338(&DAT_100b08ce0,&DAT_100933100);
  (*(code *)PTR____chkstk_darwin_100a82610)
            (*(long *)(*(long *)(puVar8 + -8) + 0x40) + 0xfU & 0xfffffffffffffff0);
  puVar23 = auStack_d0 + -extraout_x8;
  puVar8 = &DAT_100b08ca8;
  FUN_100003338(&DAT_100b08ca8,&DAT_100932700);
  (*(code *)PTR____chkstk_darwin_100a82610)
            (*(long *)(*(long *)(puVar8 + -8) + 0x40) + 0xfU & 0xfffffffffffffff0);
  lVar24 = (long)puVar23 - extraout_x8_00;
  lVar6 = 0;
  FUN_10019b3dc();
  lVar14 = *(long *)(lVar6 + -8);
  lVar20 = *(long *)(lVar14 + 0x40);
  (*(code *)PTR____chkstk_darwin_100a82610)();
  lVar15 = lVar24 - (lVar20 + 0xfU & 0xfffffffffffffff0);
  (*(code *)PTR____chkstk_darwin_100a82610)();
  lVar16 = lVar15 - extraout_x12;
  (*(code *)PTR____chkstk_darwin_100a82610)();
  uVar17 = lVar16 - extraout_x12_00;
  IVar18 = *(ID *)(unaff_x20 + 0x10);
  lVar13 = *(long *)(unaff_x20 + 0x18);
  IVar21 = *(ID *)(lVar13 + 0x10);
  IVar7 = _objc_msgSend(IVar18,"changeCount");
  if (IVar21 == 0xffffffffffffffff) {
    *(ID *)(lVar13 + 0x10) = IVar7;
    return;
  }
  if (IVar21 == IVar7) {
    return;
  }
  IVar7 = _objc_msgSend(IVar18,"changeCount");
  *(ID *)(lVar13 + 0x10) = IVar7;
  FUN_1001cd30c(0);
  _swift_initStaticObject();
  FUN_1001ccc54(lVar24);
  lVar13 = lVar24;
  (**(code **)(lVar14 + 0x30))(lVar24,1,lVar6);
  if ((int)lVar13 == 1) {
    FUN_100005828(lVar24,&DAT_100b08ca8,&DAT_100932700);
    return;
  }
  FUN_1000058a4(lVar24,uVar17,FUN_10019b3dc);
  uVar22 = uVar17;
  FUN_10013f3d8();
  if (((uVar22 & 1) == 0) ||
     (puVar8 = (undefined *)_objc_msgSend(IVar18,"pasteboardItems"), puVar8 == (undefined *)0x0))
  goto LAB_100134a6c;
  FUN_1001355f8(0);
  (extension_Foundation)::Swift::Array<undefined>::__unconditionallyBridgeFromObjectiveC();
  if ((ulong)puVar8 >> 0x3e == 0) {
    _Var25 = *(long *)(((ulong)puVar8 & 0xffffffffffffff8) + 0x10);
  }
  else {
    _Var2.unknown = (undefined *)((ulong)puVar8 & 0xffffffffffffff8);
    if ((long)puVar8 < 0) {
      _Var2.unknown = puVar8;
    }
    _Var25 = Swift::_CocoaArrayWrapper::get_endIndex(_Var2);
  }
  _swift_bridgeObjectRelease(puVar8);
  if ((_Var25 == 0) ||
     (puVar8 = (undefined *)_objc_msgSend(IVar18,"pasteboardItems"), puVar8 == (undefined *)0x0))
  goto LAB_100134a6c;
  (extension_Foundation)::Swift::Array<undefined>::__unconditionallyBridgeFromObjectiveC();
  puVar9 = puVar8;
  FUN_10013f900();
  if (((ulong)puVar9 & 1) == 0) {
    FUN_100005868(uVar17,FUN_10019b3dc);
    _swift_bridgeObjectRelease(puVar8);
    return;
  }
  local_c8 = lVar16;
  if ((ulong)puVar8 >> 0x3e == 0) {
    uVar22 = *(ulong *)(((ulong)puVar8 & 0xffffffffffffff8) + 0x10);
    if (uVar22 == 0) goto LAB_100134758;
LAB_1001345f8:
    local_b8 = (ulong)puVar8 & 0xc000000000000001;
    local_c0 = PTR___swiftEmptyArrayStorage_100a866b8;
    uVar19 = 0;
    do {
      while( true ) {
        if (local_b8 == 0) {
          if (*(ulong *)(((ulong)puVar8 & 0xffffffffffffff8) + 0x10) <= uVar19) {
                    /* WARNING: Does not return */
            pcVar4 = (code *)SoftwareBreakpoint(1,0x100134720);
            (*pcVar4)();
          }
          uVar10 = *(ulong *)(puVar8 + uVar19 * 8 + 0x20);
        }
        else {
          uVar10 = uVar19;
          FUN_100187598(uVar19,puVar8);
        }
        uVar1 = uVar19 + 1;
        if (SCARRY8(uVar19,1)) {
                    /* WARNING: Does not return */
          pcVar4 = (code *)SoftwareBreakpoint(1,0x10013471c);
          (*pcVar4)();
        }
        uVar11 = uVar10;
        FUN_10013fd5c();
        puVar9 = local_c0;
        if ((uVar11 & 1) != 0) break;
        uVar19 = uVar19 + 1;
        if (uVar1 == uVar22) goto LAB_100134764;
      }
      puVar12 = local_c0;
      _swift_isUniquelyReferenced_nonNull_native();
      local_90 = puVar9;
      if (((ulong)puVar12 & 1) == 0) {
        FUN_1001881c4(0,*(long *)(puVar9 + 0x10) + 1,1);
      }
      uVar19 = *(ulong *)(local_90 + 0x10);
      local_c0 = (undefined *)(uVar19 + 1);
      if (*(ulong *)(local_90 + 0x18) >> 1 <= uVar19) {
        FUN_1001881c4(1 < *(ulong *)(local_90 + 0x18),local_c0,1);
      }
      *(undefined **)(local_90 + 0x10) = local_c0;
      *(ulong *)(local_90 + uVar19 * 8 + 0x20) = uVar10;
      uVar19 = uVar1;
      local_c0 = local_90;
    } while (uVar1 != uVar22);
  }
  else {
    _Var2.unknown = (undefined *)((ulong)puVar8 & 0xffffffffffffff8);
    if ((long)puVar8 < 0) {
      _Var2.unknown = puVar8;
    }
    uVar22 = Swift::_CocoaArrayWrapper::get_endIndex(_Var2);
    if (uVar22 != 0) goto LAB_1001345f8;
LAB_100134758:
    local_c0 = PTR___swiftEmptyArrayStorage_100a866b8;
  }
LAB_100134764:
  _swift_bridgeObjectRelease(puVar8);
  if (DAT_100b068c8 != -1) {
    _swift_once(&DAT_100b068c8,FUN_10008e4cc);
  }
  puVar8 = local_c0;
  if (*(char *)(DAT_100c0ebc0 + _TtC8PastePal17PasteStackManager::isActive) == '\x01') {
    FUN_100090814(local_c0);
    _swift_release(puVar8);
  }
  else {
    if (DAT_100b06910 != -1) {
      _swift_once(&DAT_100b06910,FUN_1000c7de4);
    }
    puVar8 = local_c0;
    puVar9 = local_c0;
    FUN_100135ea4(local_c0);
    _swift_release(puVar8);
    lVar13 = 0;
    FUN_1001a4330();
    (**(code **)(*(long *)(lVar13 + -8) + 0x38))(puVar23,1,1,lVar13);
    FUN_100134b00(puVar9,puVar23,0,0,uVar17);
    _swift_bridgeObjectRelease(puVar9);
    FUN_100005828(puVar23,&DAT_100b08ce0,&DAT_100933100);
    if (DAT_100b069a8 != -1) {
      _swift_once(&DAT_100b069a8,FUN_10017b4c8);
    }
    lVar13 = local_c8;
    uVar3 = DAT_100c0ed40;
    if (DAT_100b069b0 != -1) {
      _swift_once(&DAT_100b069b0,FUN_10017c9a8);
    }
    IVar18 = *(ID *)(DAT_100c0ed48 + 0x18);
    if (IVar18 != 0) {
      puVar8 = &DAT_100942ae8;
      _swift_getKeyPath(&DAT_100942ae8);
      puVar9 = &DAT_100942b10;
      _swift_getKeyPath(&DAT_100942b10);
      Combine::Published::_get_subscript(&local_90,uVar3,puVar8,puVar9);
      _swift_release(puVar8);
      _swift_release(puVar9);
      puVar8 = local_90;
      uVar22 = 0;
      uVar19 = *(ulong *)(local_90 + 0x10);
      do {
        if (uVar19 == uVar22) {
          _swift_bridgeObjectRelease(puVar8);
          puVar8 = &DAT_100a95f68;
          _swift_allocObject(&DAT_100a95f68,0x18,7);
          _swift_unknownObjectWeakInit(puVar8 + 0x10,IVar18);
          FUN_1000057e4(uVar17,lVar15,FUN_10019b3dc);
          uVar22 = (ulong)*(byte *)(lVar14 + 0x50);
          uVar19 = uVar22 + 0x18 & (uVar22 ^ 0xffffffffffffffff);
          puVar9 = &DAT_100a95f90;
          _swift_allocObject(&DAT_100a95f90,uVar19 + lVar20,uVar22 | 7);
          *(undefined **)(puVar9 + 0x10) = puVar8;
          FUN_1000058a4(lVar15,puVar9 + uVar19,FUN_10019b3dc);
          local_70 = FUN_100135710;
          local_90 = PTR___NSConcreteStackBlock_100a82608;
          local_88 = 0x42000000;
          local_80 = thunk_FUN_100184578;
          puStack_78 = &DAT_100a95fa8;
          local_68 = puVar9;
          aBlock = __Block_copy(&local_90);
          _swift_release(local_68);
          _objc_msgSend(IVar18,"performBlock:",aBlock);
          __Block_release(aBlock);
          goto LAB_100134a6c;
        }
        if (*(ulong *)(puVar8 + 0x10) <= uVar22) {
                    /* WARNING: Does not return */
          pcVar4 = (code *)SoftwareBreakpoint(1,0x100134aa0);
          (*pcVar4)();
        }
        FUN_1000057e4(puVar8 + *(long *)(lVar14 + 0x48) * uVar22 +
                               ((ulong)*(byte *)(lVar14 + 0x50) + 0x20 &
                               ((ulong)*(byte *)(lVar14 + 0x50) ^ 0xffffffffffffffff)),lVar13,
                      FUN_10019b3dc);
        if (*(undefined **)(lVar13 + 8) == *(undefined **)(uVar17 + 8) &&
            *(undefined **)(lVar13 + 0x10) == *(undefined **)(uVar17 + 0x10)) {
          FUN_100005868(lVar13,FUN_10019b3dc);
          break;
        }
        uVar22 = uVar22 + 1;
        bVar5 = Swift::_stringCompareWithSmolCheck
                          ((_StringGuts)*(undefined **)(lVar13 + 8),
                           (_StringGuts)*(undefined **)(lVar13 + 0x10),
                           (_StringComparisonResult)(__int8)*(undefined **)(uVar17 + 8));
        FUN_100005868(lVar13,FUN_10019b3dc);
      } while (!bVar5);
      _swift_bridgeObjectRelease(puVar8);
    }
  }
LAB_100134a6c:
  FUN_100005868(uVar17,FUN_10019b3dc);
  return;
}


