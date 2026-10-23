// 仅反编译通过 Objective-C 元数据定位的剪贴板方法；不执行目标。
// @category XPastepal
import ghidra.app.script.GhidraScript;
import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileResults;
import ghidra.program.model.address.Address;
import ghidra.program.model.listing.Function;
import java.nio.file.Files;
import java.nio.file.Path;

public class TargetedDecompile extends GhidraScript {
    public void run() throws Exception {
        Path output = Path.of(getScriptArgs()[0]);
        Files.createDirectories(output);
        String[] addresses = { "100134364", "10013f3d8", "10013f900", "10013fd5c", "1001af3a8", "1001af49c", "1001ae8ac", "1001ae8e8" };
        DecompInterface decompiler = new DecompInterface();
        decompiler.openProgram(currentProgram);
        try {
            for (String value : addresses) {
                Address address = toAddr(value);
                disassemble(address);
                Function function = getFunctionAt(address);
                if (function == null) function = createFunction(address, "clipboard_method_" + value);
                if (function == null) { println("NO_FUNCTION " + value); continue; }
                DecompileResults result = decompiler.decompileFunction(function, 40, monitor);
                String content = "/* Ghidra 12.1.4, arm64, -noanalysis; method address 0x" + value + " */\n";
                if (result.decompileCompleted() && result.getDecompiledFunction() != null) {
                    content += result.getDecompiledFunction().getC();
                    println("DECOMPILED " + value);
                } else {
                    content += "/* FAILED: " + result.getErrorMessage() + " */\n";
                    println("FAILED " + value + " " + result.getErrorMessage());
                }
                Files.writeString(output.resolve(value + ".c"), content);
            }
        } finally { decompiler.dispose(); }
    }
}
