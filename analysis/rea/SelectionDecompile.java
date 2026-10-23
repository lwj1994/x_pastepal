// Decompile selection methods identified through Objective-C metadata; never execute the target.
// @category XPastepal
import ghidra.app.script.GhidraScript;
import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileResults;
import ghidra.program.model.address.Address;
import ghidra.program.model.listing.Function;
import java.nio.file.Files;
import java.nio.file.Path;

public class SelectionDecompile extends GhidraScript {
    public void run() throws Exception {
        Path output = Path.of(getScriptArgs()[0]);
        Files.createDirectories(output);
        String[] addresses = { "100179cbc", "10015af14", "10015ab98", "10015b084", "10016583c", "1001644cc" };
        DecompInterface decompiler = new DecompInterface();
        decompiler.openProgram(currentProgram);
        try {
            for (String value : addresses) {
                Address address = toAddr(value);
                disassemble(address);
                Function function = getFunctionAt(address);
                if (function == null) function = createFunction(address, "selection_method_" + value);
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
