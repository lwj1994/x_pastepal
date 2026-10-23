/* Ghidra 12.1.4, arm64, -noanalysis; method address 0x1001ae8e8 */

undefined1 *
clipboard_method_1001ae8e8
          (undefined8 param_1,undefined8 param_2,undefined8 param_3,undefined8 param_4)

{
  undefined8 uVar1;
  undefined1 *puVar2;
  undefined8 *puVar3;
  undefined8 uStack_70;
  undefined8 uStack_68;
  undefined1 auStack_60 [24];
  undefined8 uStack_48;
  
  puVar3 = &uStack_70;
  uVar1 = param_1;
  _swift_getObjectType();
  _swift_unknownObjectRetain(param_3);
  _objc_retain(param_4);
  __ss018_bridgeAnyObjectToB0yypyXlSgF(auStack_60,param_3);
  _swift_unknownObjectRelease(param_3);
  puVar2 = auStack_60;
  func_0x00010005a0b4(puVar2,uStack_48);
  __ss27_bridgeAnythingToObjectiveCyyXlxlF();
  uStack_70 = param_1;
  uStack_68 = uVar1;
  _objc_msgSendSuper2(&uStack_70,PTR_s_initWithPasteboardPropertyList_o_100af9f80,puVar2,param_4);
  _objc_retainAutoreleasedReturnValue();
  _objc_release(param_4);
  _swift_unknownObjectRelease(puVar2);
  func_0x00010003634c(auStack_60);
  if (puVar3 != (undefined8 *)0x0) {
    _objc_release(puVar3);
  }
  return (undefined1 *)puVar3;
}

