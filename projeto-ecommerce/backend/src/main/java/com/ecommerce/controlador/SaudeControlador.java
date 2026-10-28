package com.ecommerce.controlador;

import com.ecommerce.repositorio.RepositorioAdmin;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.Map;

@RestController
public class SaudeControlador {

    private final RepositorioAdmin repositorio;

    public SaudeControlador(RepositorioAdmin repositorio) {
        this.repositorio = repositorio;
    }

    /** Faz uma query a BD (SELECT COUNT(*) FROM sys.tables); se falhar devolve bd:false sem rebentar. */
    @GetMapping("/api/health")
    public Map<String, Object> saude() {
        Map<String, Object> r = new LinkedHashMap<>();
        r.put("status", "OK");
        try {
            r.put("tabelas", repositorio.contarTabelas());
            r.put("bd", true);
        } catch (Exception e) {
            r.put("tabelas", 0);
            r.put("bd", false);
            // Causa real da falha (ligacao, login, porta...) para facilitar o diagnostico
            Throwable causa = e;
            while (causa.getCause() != null && causa.getCause() != causa) {
                causa = causa.getCause();
            }
            r.put("erro", causa.getMessage());
        }
        r.put("timestamp", Instant.now().toString());
        return r;
    }
}
