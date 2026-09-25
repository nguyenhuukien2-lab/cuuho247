package com.example.roadside.data.repository;

import android.content.Context;

import com.example.roadside.data.db.AppDatabase;
import com.example.roadside.data.db.RequestDao;
import com.example.roadside.data.models.Request;

import java.util.List;

public class RequestRepository {

    private final RequestDao requestDao;

    public RequestRepository(Context context) {
        AppDatabase db = AppDatabase.getInstance(context);
        requestDao = db.requestDao();
    }

    public long createRequest(Request request) {
        return requestDao.insert(request);
    }

    public Request getRequestById(int id) {
        return requestDao.getRequestById(id);
    }

    public List<Request> getRequestsForUser(int userId) {
        return requestDao.getRequestsByUserId(userId);
    }

    public void updateRequest(Request request) {
        requestDao.update(request);
    }
}
