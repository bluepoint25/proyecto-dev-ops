package cl.pedidos360.backend;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.util.List;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.test.web.servlet.MockMvc;

/**
 * Verifica la politica de seguridad por scopes del CRUD de productos:
 * 401 sin token, 403 sin el scope requerido y 200/201 con el scope correcto.
 */
@WebMvcTest(ProductoController.class)
@Import(SecurityConfig.class)
class ProductoControllerTest {

    private static final String JSON = "{\"nombre\":\"Teclado\",\"precio\":15000,\"stock\":4}";

    @Autowired
    private MockMvc mvc;

    @MockBean
    private ProductoRepository repo;

    // Evita que Spring contacte a Cognito para descubrir el JWKS durante los tests
    @MockBean
    private JwtDecoder jwtDecoder;

    @Test
    void listarSinTokenRetorna401() throws Exception {
        mvc.perform(get("/productos")).andExpect(status().isUnauthorized());
    }

    @Test
    void listarConScopeReadRetorna200() throws Exception {
        when(repo.findAll()).thenReturn(List.of(new Producto("Mouse", 9990, 10)));

        mvc.perform(get("/productos")
                .with(jwt().authorities(new SimpleGrantedAuthority("SCOPE_productos/read"))))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$[0].nombre").value("Mouse"))
            .andExpect(jsonPath("$[0].precio").value(9990));
    }

    @Test
    void listarSinScopeReadRetorna403() throws Exception {
        mvc.perform(get("/productos")
                .with(jwt().authorities(new SimpleGrantedAuthority("SCOPE_otro/scope"))))
            .andExpect(status().isForbidden());
    }

    @Test
    void crearConScopeReadRetorna403() throws Exception {
        mvc.perform(post("/productos")
                .with(jwt().authorities(new SimpleGrantedAuthority("SCOPE_productos/read")))
                .contentType(MediaType.APPLICATION_JSON)
                .content(JSON))
            .andExpect(status().isForbidden());
    }

    @Test
    void crearConPrecioNegativoRetorna400() throws Exception {
        mvc.perform(post("/productos")
                .with(jwt().authorities(new SimpleGrantedAuthority("SCOPE_productos/write")))
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"nombre\":\"Teclado\",\"precio\":-1,\"stock\":4}"))
            .andExpect(status().isBadRequest());
    }

    @Test
    void crearSinNombreRetorna400() throws Exception {
        mvc.perform(post("/productos")
                .with(jwt().authorities(new SimpleGrantedAuthority("SCOPE_productos/write")))
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"nombre\":\"  \",\"precio\":100,\"stock\":4}"))
            .andExpect(status().isBadRequest());
    }

    @Test
    void crearConScopeWriteRetorna201() throws Exception {
        when(repo.save(any(Producto.class))).thenAnswer(inv -> inv.getArgument(0));

        mvc.perform(post("/productos")
                .with(jwt().authorities(new SimpleGrantedAuthority("SCOPE_productos/write")))
                .contentType(MediaType.APPLICATION_JSON)
                .content(JSON))
            .andExpect(status().isCreated())
            .andExpect(jsonPath("$.nombre").value("Teclado"));

        verify(repo).save(any(Producto.class));
    }
}
