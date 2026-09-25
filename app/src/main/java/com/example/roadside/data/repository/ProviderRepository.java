package com.example.roadside.data.repository;

import com.example.roadside.data.models.Provider;

import java.util.ArrayList;
import java.util.List;

public class ProviderRepository {

    public List<Provider> getMockProviders() {
        List<Provider> list = new ArrayList<>();
        list.add(new Provider(1, "Cứu Hộ Nhanh 24/7", "0901234567", 4.9, 10.7769, 106.7009, "Xe Kéo Chuyên Dụng", true, 1.2));
        list.add(new Provider(2, "Cứu Hộ Sài Gòn", "0908765432", 4.7, 10.7800, 106.7050, "Xe Cứu Hộ Đa Năng", true, 2.5));
        list.add(new Provider(3, "Đội Cứu Hộ Lưu Động", "0912345678", 4.8, 10.7700, 106.6900, "Sửa Chữa Tận Nơi", true, 3.8));
        return list;
    }
}
