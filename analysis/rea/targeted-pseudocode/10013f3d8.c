/* Ghidra 12.1.4, arm64, -noanalysis; method address 0x10013f3d8 */

bool clipboard_method_10013f3d8(long param_1)

{
  ulong *puVar1;
  undefined8 uVar2;
  code *pcVar3;
  long lVar4;
  long lVar5;
  undefined *puVar6;
  undefined *puVar7;
  ulong uVar8;
  long extraout_x8;
  long extraout_x12;
  bool bVar9;
  undefined1 *puVar10;
  ulong uVar11;
  long lVar12;
  ulong uVar13;
  undefined1 auStack_120 [8];
  undefined8 uStack_118;
  undefined8 uStack_110;
  undefined8 uStack_108;
  undefined8 uStack_100;
  long lStack_f8;
  long lStack_f0;
  undefined8 uStack_e8;
  undefined8 uStack_e0;
  undefined8 uStack_d8;
  undefined8 uStack_c0;
  undefined8 uStack_b8;
  undefined8 uStack_b0;
  undefined8 uStack_a8;
  long lStack_a0;
  long lStack_98;
  undefined8 uStack_90;
  undefined8 uStack_88;
  undefined8 uStack_80;
  
  lVar4 = 0;
  func_0x0001001c1788();
  lVar12 = *(long *)(lVar4 + -8);
  (*(code *)PTR____chkstk_darwin_100a82610)(*(undefined8 *)(lVar12 + 0x40));
  puVar10 = auStack_120 + -(extraout_x8 + 0xfU & 0xfffffffffffffff0);
  (*(code *)PTR____chkstk_darwin_100a82610)();
  lVar4 = (long)puVar10 - extraout_x12;
  if (lRam0000000100b06970 != -1) {
    _swift_once(0x100b06970,&DAT_10013e83c);
  }
  uVar2 = uRam0000000100c0ed20;
  lVar5 = 0;
  func_0x00010019b3dc();
  puVar1 = (ulong *)(param_1 + *(int *)(lVar5 + 0x1c));
  uVar11 = *puVar1;
  func_0x00010003dfd0(uVar11,puVar1[1],uVar2);
  if ((uVar11 & 1) == 0) {
    if (lRam0000000100b06ab0 != -1) {
      _swift_once(0x100b06ab0,&DAT_1001c5bf4);
    }
    uVar2 = uRam0000000100c0efc8;
    puVar6 = &UNK_100942cc0;
    _swift_getKeyPath(&UNK_100942cc0);
    puVar7 = &UNK_100942ce8;
    _swift_getKeyPath(&UNK_100942ce8);
    __s7Combine9PublishedV18_enclosingInstance7wrapped7storagexqd___s24ReferenceWritableKeyPathCyqd__xGAHyqd__ACyxGGtcRld__CluigZ
              (&uStack_118,uVar2,puVar6,puVar7);
    _swift_release(puVar6);
    _swift_release(puVar7);
    uStack_88 = uStack_e0;
    uStack_90 = uStack_e8;
    uStack_80 = uStack_d8;
    uStack_b8 = uStack_110;
    uStack_c0 = uStack_118;
    uStack_a8 = uStack_100;
    uStack_b0 = uStack_108;
    lStack_98 = lStack_f0;
    lStack_a0 = lStack_f8;
    uVar11 = *(ulong *)(lStack_f8 + 0x10);
    if (uVar11 == 0) {
      uVar11 = *(ulong *)(lStack_f0 + 0x10);
      if (uVar11 == 0) {
LAB_10013f60c:
        func_0x000100033c58(&uStack_c0);
        bVar9 = true;
      }
      else {
        uVar13 = 0;
        do {
          if (uVar11 == uVar13) goto LAB_10013f60c;
          if (*(ulong *)(lStack_f0 + 0x10) <= uVar13) {
                    /* WARNING: Does not return */
            pcVar3 = (code *)SoftwareBreakpoint(1,0x10013f644);
            (*pcVar3)();
          }
          func_0x0001001401f0(lStack_f0 +
                              ((ulong)*(byte *)(lVar12 + 0x50) + 0x20 &
                              ((ulong)*(byte *)(lVar12 + 0x50) ^ 0xffffffffffffffff)) +
                              *(long *)(lVar12 + 0x48) * uVar13,puVar10);
          uVar13 = uVar13 + 1;
          uVar8 = param_1 + *(int *)(lVar5 + 0x18);
          __s10Foundation3URLV2eeoiySbAC_ACtFZ(uVar8,puVar10);
          func_0x000100140234(puVar10);
        } while ((uVar8 & 1) == 0);
        func_0x000100033c58(&uStack_c0);
        bVar9 = false;
      }
    }
    else {
      uVar13 = 0;
      do {
        bVar9 = uVar11 != uVar13;
        if (uVar11 == uVar13) break;
        if (*(ulong *)(lStack_f8 + 0x10) <= uVar13) {
                    /* WARNING: Does not return */
          pcVar3 = (code *)SoftwareBreakpoint(1,0x10013f640);
          (*pcVar3)();
        }
        func_0x0001001401f0(lStack_f8 +
                            ((ulong)*(byte *)(lVar12 + 0x50) + 0x20 &
                            ((ulong)*(byte *)(lVar12 + 0x50) ^ 0xffffffffffffffff)) +
                            *(long *)(lVar12 + 0x48) * uVar13,lVar4);
        uVar13 = uVar13 + 1;
        uVar8 = param_1 + *(int *)(lVar5 + 0x18);
        __s10Foundation3URLV2eeoiySbAC_ACtFZ(uVar8,lVar4);
        func_0x000100140234(lVar4);
      } while ((uVar8 & 1) == 0);
      func_0x000100033c58(&uStack_c0);
    }
  }
  else {
    bVar9 = false;
  }
  return bVar9;
}

