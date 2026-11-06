package com.shopease.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.shopease.model.Product;
import com.shopease.repository.ProductRepository;
import java.math.BigDecimal;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class ProductServiceTest {

    @Mock
    private ProductRepository repository;

    @InjectMocks
    private ProductService service;

    private Product mouse() {
        return new Product("Mouse", "optical", new BigDecimal("10.00"), 5);
    }

    @Test
    void getReturnsProductWhenPresent() {
        when(repository.findById(1L)).thenReturn(Optional.of(mouse()));

        assertThat(service.get(1L).getName()).isEqualTo("Mouse");
    }

    @Test
    void getThrowsWhenMissing() {
        when(repository.findById(99L)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.get(99L)).isInstanceOf(NotFoundException.class);
    }

    @Test
    void reduceStockLowersTheStock() {
        Product product = mouse();
        when(repository.findById(1L)).thenReturn(Optional.of(product));

        service.reduceStock(1L, 2);

        assertThat(product.getStock()).isEqualTo(3);
        verify(repository).save(product);
    }

    @Test
    void reduceStockRejectsWhenInsufficient() {
        when(repository.findById(1L)).thenReturn(Optional.of(mouse()));

        assertThatThrownBy(() -> service.reduceStock(1L, 6))
                .isInstanceOf(BadRequestException.class)
                .hasMessageContaining("Insufficient stock");
    }
}
