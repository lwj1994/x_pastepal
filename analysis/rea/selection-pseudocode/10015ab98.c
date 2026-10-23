/* Ghidra 12.1.4, arm64, -noanalysis; method address 0x10015ab98 */

/* WARNING: Globals starting with '_' overlap smaller symbols at the same address */

void selection_method_10015ab98(void)

{
  long lVar1;
  undefined *puVar2;
  undefined *puVar3;
  undefined8 uVar4;
  long unaff_x20;
  
  lVar1 = unaff_x20;
  _objc_msgSend();
  uVar4 = *(undefined8 *)(unaff_x20 + _DAT_100b12de0);
  puVar2 = PTR__OBJC_CLASS___NSColor_100afc3b0;
  _objc_opt_self(PTR__OBJC_CLASS___NSColor_100afc3b0);
  if ((int)lVar1 == 0) {
    _objc_msgSend(0x3fd3333333333333,_UNK_100933998);
  }
  else {
    _objc_msgSend();
  }
  _objc_retainAutoreleasedReturnValue();
  puVar3 = puVar2;
  _objc_msgSend();
  _objc_retainAutoreleasedReturnValue();
  _objc_release(puVar2);
  _objc_msgSend(uVar4,PTR_s_setStrokeColor__100af9b20,puVar3);
                    /* WARNING: Could not recover jumptable at 0x0001008cec4c. Too many branches */
                    /* WARNING: Treating indirect jump as call */
  (*(code *)PTR__objc_release_100a825c8)(puVar3);
  return;
}

