package com.shopease.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.shopease.model.Order;
import com.shopease.repository.OrderRepository;
import java.math.BigDecimal;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class OrderServiceTest {

    @Mock
    private CartService carts;

    @Mock
    private ProductService products;

    @Mock
    private OrderRepository orders;

    @InjectMocks
    private OrderService service;

    @Test
    void checkoutOfEmptyCartIsRejected() {
        when(carts.view("c1")).thenReturn(new CartView("c1", List.of(), BigDecimal.ZERO));

        assertThatThrownBy(() -> service.checkout("c1", "Asha")).isInstanceOf(BadRequestException.class);
        verify(orders, never()).save(any());
    }

    @Test
    void checkoutReducesStockSavesOrderAndClearsCart() {
        CartLine line = new CartLine(1L, "Mouse", new BigDecimal("10.00"), 2, new BigDecimal("20.00"));
        when(carts.view("c1")).thenReturn(new CartView("c1", List.of(line), new BigDecimal("20.00")));
        when(orders.save(any(Order.class))).thenAnswer(inv -> inv.getArgument(0));

        Order order = service.checkout("c1", "Asha");

        assertThat(order.getCustomerName()).isEqualTo("Asha");
        assertThat(order.getTotal()).isEqualByComparingTo("20.00");
        assertThat(order.getLines()).hasSize(1);
        verify(products).reduceStock(1L, 2);
        verify(carts).clear("c1");
    }
}
