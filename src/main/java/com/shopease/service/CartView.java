package com.shopease.service;

import java.math.BigDecimal;
import java.util.List;

public record CartView(String cartId, List<CartLine> lines, BigDecimal total) {
}
