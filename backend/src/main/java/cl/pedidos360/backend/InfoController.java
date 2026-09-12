package cl.pedidos360.backend;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

/**
 * GET /info — endpoint público de metadatos del servicio.
 *
 * Expone nombre y versión del microservicio para observabilidad (útil en un
 * pipeline DevOps para verificar rápidamente qué versión está desplegada).
 * Es público: no maneja datos sensibles y facilita los health/smoke checks.
 */
@RestController
@RequestMapping("/info")
public class InfoController {

    @GetMapping
    public Map<String, String> info() {
        return Map.of(
            "servicio", "pedidos360-backend",
            "version", "1.1.0",
            "estado", "ok"
        );
    }
}
