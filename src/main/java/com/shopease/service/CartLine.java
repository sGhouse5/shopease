package com.shopease.service;

import java.math.BigDecimal;

public record CartLine(Long productId, String name, BigDecimal unitPrice, int quantity, BigDecimal lineTotal) {
}
