/* Ghidra 12.1.4, arm64, -noanalysis; method address 0x1001af3a8 */

void clipboard_method_1001af3a8
               (undefined8 param_1,undefined8 param_2,undefined8 param_3,undefined8 param_4,
               undefined8 param_5)

{
  long lVar1;
  undefined *puVar2;
  long extraout_x8;
  
  lVar1 = 0x100b09558;
  func_0x000100003338(0x100b09558,&UNK_1009350d0);
  (*(code *)PTR____chkstk_darwin_100a82610)
            (*(long *)(*(long *)(lVar1 + -8) + 0x40) + 0xfU & 0xfffffffffffffff0);
  lVar1 = 0;
  __sScPMa();
  (**(code **)(*(long *)(lVar1 + -8) + 0x38))(&stack0xffffffffffffffc0 + -extraout_x8,1,1,lVar1);
  puVar2 = &UNK_100a99570;
  _swift_allocObject(&UNK_100a99570,0x38,7);
  *(undefined8 *)(puVar2 + 0x10) = 0;
  *(undefined8 *)(puVar2 + 0x18) = 0;
  *(undefined8 *)(puVar2 + 0x20) = param_5;
  *(undefined8 *)(puVar2 + 0x28) = param_1;
  *(undefined8 *)(puVar2 + 0x30) = param_4;
  _objc_retain(param_4);
  _objc_retain(param_5);
  _objc_retain(param_1);
  func_0x000100090ee8(0,0,&stack0xffffffffffffffc0 + -extraout_x8,&UNK_100945e98,puVar2);
  _swift_release();
  return;
}

