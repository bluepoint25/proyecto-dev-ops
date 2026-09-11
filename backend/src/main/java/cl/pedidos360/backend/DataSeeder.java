package cl.pedidos360.backend;

import org.springframework.boot.CommandLineRunner;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * Inserta 3 productos iniciales si la tabla está vacía.
 */
@Configuration
public class DataSeeder {

    @Bean
    CommandLineRunner seed(ProductoRepository repo) {
        return args -> {
            if (repo.count() == 0) {
                repo.save(new Producto("Laptop Pro 15\"", 899990, 10));
                repo.save(new Producto("Mouse Inalambrico", 24990, 50));
                repo.save(new Producto("Teclado Mecanico", 59990, 25));
            }
        };
    }
}
