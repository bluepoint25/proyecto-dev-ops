package cl.pedidos360.backend;

import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/productos")
public class ProductoController {

    private final ProductoRepository repo;

    public ProductoController(ProductoRepository repo) {
        this.repo = repo;
    }

    /**
     * GET /productos — cualquier usuario autenticado con scope productos/read.
     * El API Gateway ya valida el scope; aquí lo reforzamos (defensa en profundidad).
     */
    @GetMapping
    @PreAuthorize("hasAuthority('SCOPE_productos/read')")
    public List<Producto> listar() {
        return repo.findAll();
    }

    /**
     * POST /productos — solo usuarios con scope productos/write (grupo editores).
     * Si el token no trae el scope, Spring responde 403 Forbidden.
     */
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    @PreAuthorize("hasAuthority('SCOPE_productos/write')")
    public Producto crear(@RequestBody Producto producto) {
        return repo.save(producto);
    }
}
