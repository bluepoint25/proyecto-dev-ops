package cl.pedidos360.backend;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.jdbc.AutoConfigureTestDatabase;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

/**
 * Prueba de integracion contra PostgreSQL real (el mismo motor de RDS/staging),
 * no contra H2. Se omite sola si la maquina no tiene Docker.
 */
@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@Testcontainers(disabledWithoutDocker = true)
class ProductoRepositoryPostgresTest {

    @Container
    @ServiceConnection
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16-alpine");

    @Autowired
    private ProductoRepository repo;

    @Test
    void guardaYLeeProductoEnPostgres() {
        Producto guardado = repo.save(new Producto("Notebook", 550000, 3));

        assertThat(guardado.getId()).isNotNull();
        assertThat(repo.findById(guardado.getId()))
            .get()
            .extracting(Producto::getNombre, Producto::getStock)
            .containsExactly("Notebook", 3);
    }
}
