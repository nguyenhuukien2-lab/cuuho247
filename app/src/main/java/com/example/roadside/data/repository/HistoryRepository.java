package com.example.roadside.data.repository;

import android.content.Context;

import com.example.roadside.data.db.AppDatabase;
import com.example.roadside.data.db.RequestDao;
import com.example.roadside.data.models.Request;

import java.util.List;

public class HistoryRepository {

    private final RequestDao requestDao;

    public HistoryRepository(Context context) {
        AppDatabase db = AppDatabase.getInstance(context);
        requestDao = db.requestDao();
    }

    public List<Request> getHistory(int userId) {
        return requestDao.getRequestsByUserId(userId);
    }
}
