package cl.pedidos360.backend;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;

/** Levanta el contexto completo con H2: seeder, persistencia y endpoints publicos. */
@SpringBootTest
@AutoConfigureMockMvc
@Transactional
class BackendApplicationTests {

    @MockBean
    private JwtDecoder jwtDecoder;

    @Autowired
    private ProductoRepository repo;

    @Autowired
    private MockMvc mvc;

    @Test
    void contextoCargaYSeederInsertaProductos() {
        assertThat(repo.count()).isPositive();
    }

    @Test
    void persisteUnProducto() {
        Producto guardado = repo.save(new Producto("Monitor", 120000, 2));
        assertThat(guardado.getId()).isNotNull();
        assertThat(repo.findById(guardado.getId())).isPresent();
    }

    // Las probes de Kubernetes consultan estas rutas sin token
    @Test
    void probesDeSaludSonPublicas() throws Exception {
        mvc.perform(get("/actuator/health")).andExpect(status().isOk());
        mvc.perform(get("/actuator/health/readiness")).andExpect(status().isOk());
        mvc.perform(get("/actuator/health/liveness")).andExpect(status().isOk());
    }

    @Test
    void crearSinTokenRetorna401() throws Exception {
        mvc.perform(post("/productos").contentType(MediaType.APPLICATION_JSON).content("{}"))
            .andExpect(status().isUnauthorized());
    }
}
