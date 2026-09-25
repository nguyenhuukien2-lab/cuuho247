package com.example.roadside.utils;

import java.text.NumberFormat;
import java.util.Locale;

public class PaymentHelper {

    public static String formatCurrency(double amount) {
        NumberFormat format = NumberFormat.getCurrencyInstance(new Locale("vi", "VN"));
        return format.format(amount);
    }

    public static double calculateTotalCost(String serviceType, double distanceKm) {
        double baseFee = 200000;
        if (serviceType != null) {
            if (serviceType.contains("Kéo xe") || serviceType.contains("Towing")) {
                baseFee = 500000;
            } else if (serviceType.contains("Kích bình") || serviceType.contains("Battery")) {
                baseFee = 250000;
            } else if (serviceType.contains("Lốp") || serviceType.contains("Tire")) {
                baseFee = 200000;
            }
        }
        return baseFee + (distanceKm * 15000);
    }
}
