package cl.pedidos360.backend;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.context.annotation.Import;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.test.web.servlet.MockMvc;

/** /info es publico: sirve de smoke test del pipeline para saber que version corre. */
@WebMvcTest(InfoController.class)
@Import(SecurityConfig.class)
class InfoControllerTest {

    @Autowired
    private MockMvc mvc;

    @MockBean
    private JwtDecoder jwtDecoder;

    @Test
    void infoEsPublicoYExponeServicioYVersion() throws Exception {
        mvc.perform(get("/info"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.servicio").value("pedidos360-backend"))
            .andExpect(jsonPath("$.estado").value("ok"))
            .andExpect(jsonPath("$.version").exists());
    }
}
