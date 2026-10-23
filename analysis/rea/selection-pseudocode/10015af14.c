/* Ghidra 12.1.4, arm64, -noanalysis; method address 0x10015af14 */

void selection_method_10015af14(undefined8 param_1,undefined8 param_2,undefined8 param_3)

{
  undefined *puVar1;
  undefined8 uVar2;
  undefined8 uStack_40;
  undefined8 uStack_38;
  
  uVar2 = param_1;
  func_0x00010015b488();
  puVar1 = PTR_s_setSelected__100af9b08;
  uStack_40 = param_1;
  uStack_38 = uVar2;
  _objc_retain(param_1);
  _objc_msgSendSuper2(&uStack_40,puVar1,param_3);
  func_0x00010015ab98();
  func_0x00010015ac5c();
  _objc_release(param_1);
  return;
}

