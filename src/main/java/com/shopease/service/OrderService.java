package com.shopease.service;

import com.shopease.model.Order;
import com.shopease.model.OrderLine;
import com.shopease.repository.OrderRepository;
import java.util.List;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class OrderService {

    private final CartService carts;
    private final ProductService products;
    private final OrderRepository orders;

    public OrderService(CartService carts, ProductService products, OrderRepository orders) {
        this.carts = carts;
        this.products = products;
        this.orders = orders;
    }

    @Transactional
    public Order checkout(String cartId, String customerName) {
        CartView cart = carts.view(cartId);
        if (cart.lines().isEmpty()) {
            throw new BadRequestException("Cart is empty");
        }
        for (CartLine line : cart.lines()) {
            products.reduceStock(line.productId(), line.quantity());
        }
        List<OrderLine> lines = cart.lines().stream()
                .map(l -> new OrderLine(l.productId(), l.name(), l.unitPrice(), l.quantity()))
                .toList();
        Order saved = orders.save(new Order(customerName, cart.total(), lines));
        carts.clear(cartId);
        return saved;
    }
}
