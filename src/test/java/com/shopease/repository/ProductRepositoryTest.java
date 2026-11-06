package com.shopease.repository;

import static org.assertj.core.api.Assertions.assertThat;

import com.shopease.model.Product;
import java.math.BigDecimal;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest;

@DataJpaTest
class ProductRepositoryTest {

    @Autowired
    private ProductRepository repository;

    @Test
    void savedProductCanBeFoundAgain() {
        Product saved = repository.save(new Product("Mouse", "x", new BigDecimal("10.00"), 5));

        assertThat(repository.findById(saved.getId())).isPresent();
        assertThat(repository.count()).isEqualTo(1);
    }
}
