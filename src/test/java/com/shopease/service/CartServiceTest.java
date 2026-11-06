package com.shopease.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.when;

import com.shopease.model.Product;
import java.math.BigDecimal;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class CartServiceTest {

    @Mock
    private ProductService products;

    private CartService carts;

    @BeforeEach
    void setUp() {
        carts = new CartService(products);
    }

    @Test
    void addingTheSameProductTwiceAccumulatesQuantity() {
        when(products.get(1L)).thenReturn(new Product("Mouse", "x", new BigDecimal("10.00"), 5));

        carts.addItem("c1", 1L, 1);
        CartView cart = carts.addItem("c1", 1L, 2);

        assertThat(cart.lines()).hasSize(1);
        assertThat(cart.lines().get(0).quantity()).isEqualTo(3);
        assertThat(cart.total()).isEqualByComparingTo("30.00");
    }

    @Test
    void unknownProductIsRejected() {
        when(products.get(42L)).thenThrow(new NotFoundException("Product 42 not found"));

        assertThatThrownBy(() -> carts.addItem("c1", 42L, 1)).isInstanceOf(NotFoundException.class);
    }

    @Test
    void emptyCartHasZeroTotal() {
        CartView cart = carts.view("nobody");

        assertThat(cart.lines()).isEmpty();
        assertThat(cart.total()).isEqualByComparingTo("0");
    }

    @Test
    void clearEmptiesTheCart() {
        when(products.get(1L)).thenReturn(new Product("Mouse", "x", new BigDecimal("10.00"), 5));
        carts.addItem("c1", 1L, 1);

        carts.clear("c1");

        assertThat(carts.view("c1").lines()).isEmpty();
    }
}
