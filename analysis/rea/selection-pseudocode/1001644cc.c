/* Ghidra 12.1.4, arm64, -noanalysis; method address 0x1001644cc */

void selection_method_1001644cc
               (undefined8 param_1,undefined8 param_2,undefined8 param_3,undefined8 param_4)

{
  undefined8 uVar1;
  undefined8 uVar2;
  
  uVar1 = 0;
  __s10Foundation9IndexPathVMa(0);
  uVar2 = 0x100b0ac48;
  func_0x000100003600(0x100b0ac48,PTR___s10Foundation9IndexPathVMa_100a87c68,
                      PTR___s10Foundation9IndexPathVSHAAMc_100a87c78);
  __sSh10FoundationE36_unconditionallyBridgeFromObjectiveCyShyxGSo5NSSetCSgFZ(param_4,uVar1,uVar2);
  _objc_retain(param_3);
  _objc_retain(param_1);
  func_0x000100164dfc(param_4);
  _objc_release(param_3);
  _objc_release(param_1);
                    /* WARNING: Could not recover jumptable at 0x0001008cf084. Too many branches */
                    /* WARNING: Treating indirect jump as call */
  (*(code *)PTR__swift_bridgeObjectRelease_100a86740)(param_4);
  return;
}

