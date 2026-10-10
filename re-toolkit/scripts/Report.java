import ghidra.app.script.GhidraScript;
import ghidra.app.decompiler.*;
import ghidra.program.model.listing.*;
import ghidra.program.model.symbol.*;
import ghidra.program.model.data.StringDataInstance;
import ghidra.program.util.DefinedStringIterator;
import java.io.*;
import java.util.*;

// Writes summary.txt, imports.txt, strings.txt and decompiled.c into the directory given as script arg.
public class Report extends GhidraScript {
  public void run() throws Exception {
    File out = new File(getScriptArgs()[0]); out.mkdirs();
    Program p = currentProgram;
    FunctionManager fm = p.getFunctionManager();

    // Auto-analysis misses code reached only through a pointer (e.g. main passed to
    // __libc_start_main). Make a function at every labeled instruction outside one.
    int recovered = 0;
    SymbolTable labels = p.getSymbolTable();
    for (Instruction ins : p.getListing().getInstructions(true)) {
      var a = ins.getAddress();
      if (fm.getFunctionContaining(a) == null && labels.getPrimarySymbol(a) != null
          && createFunction(a, null) != null) {
        recovered++;
      }
    }

    try (PrintWriter w = new PrintWriter(new File(out, "imports.txt"))) {
      for (Function f : fm.getExternalFunctions()) {
        w.println(f.getExternalLocation().getLibraryName() + "!" + f.getName());
      }
    }
    int nStr = 0;
    try (PrintWriter w = new PrintWriter(new File(out, "strings.txt"))) {
      for (Data d : DefinedStringIterator.forProgram(p)) {
        StringDataInstance s = StringDataInstance.getStringDataInstance(d);
        String v = s.getStringValue();
        if (v != null && v.length() >= 4) { w.println(d.getAddress() + "  " + v.replace("\n", "\\n")); nStr++; }
      }
    }
    DecompInterface dec = new DecompInterface();
    dec.openProgram(p);
    int nFun = 0, nFail = 0;
    try (PrintWriter w = new PrintWriter(new File(out, "decompiled.c"))) {
      for (Function f : fm.getFunctions(true)) {
        if (monitor.isCancelled()) break;
        if (f.isThunk() || f.isExternal()) continue;
        DecompileResults r = dec.decompileFunction(f, 60, monitor);
        w.println("// ==== " + f.getName() + " @ " + f.getEntryPoint() + " ====");
        if (r.decompileCompleted()) { w.println(r.getDecompiledFunction().getC()); nFun++; }
        else { w.println("// decompile failed: " + r.getErrorMessage() + "\n"); nFail++; }
      }
    }
    dec.dispose();
    try (PrintWriter w = new PrintWriter(new File(out, "summary.txt"))) {
      w.println("File:       " + p.getExecutablePath());
      w.println("Format:     " + p.getExecutableFormat());
      w.println("Language:   " + p.getLanguageID() + " / " + p.getCompilerSpec().getCompilerSpecID());
      w.println("Image base: " + p.getImageBase());
      w.println("SHA-256:    " + p.getExecutableSHA256());
      w.println("Functions:  " + (nFun + nFail) + " own code (" + nFun + " decompiled, " + nFail + " failed), "
        + (fm.getFunctionCount() - nFun - nFail) + " imports/stubs skipped");
      w.println("Strings:    " + nStr);
      w.println("Recovered:  " + recovered + " functions missed by auto-analysis");
      w.print("Entry points:");
      SymbolTable st = p.getSymbolTable();
      for (var it = st.getExternalEntryPointIterator(); it.hasNext();) {
        var a = it.next(); Symbol s = st.getPrimarySymbol(a);
        w.print(" " + (s != null ? s.getName() : a.toString()));
      }
      w.println();
    }
    println("REPORT WRITTEN: " + out);
  }
}
