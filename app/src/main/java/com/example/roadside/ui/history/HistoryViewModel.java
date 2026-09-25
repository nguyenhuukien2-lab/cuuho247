package com.example.roadside.ui.history;

import android.app.Application;

import androidx.annotation.NonNull;
import androidx.lifecycle.AndroidViewModel;
import androidx.lifecycle.LiveData;
import androidx.lifecycle.MutableLiveData;

import com.example.roadside.data.models.Request;
import com.example.roadside.data.repository.HistoryRepository;
import com.example.roadside.utils.SharedPrefsHelper;

import java.util.List;

public class HistoryViewModel extends AndroidViewModel {

    private final HistoryRepository historyRepository;
    private final SharedPrefsHelper prefsHelper;
    private final MutableLiveData<List<Request>> historyList = new MutableLiveData<>();

    public HistoryViewModel(@NonNull Application application) {
        super(application);
        historyRepository = new HistoryRepository(application);
        prefsHelper = new SharedPrefsHelper(application);
    }

    public LiveData<List<Request>> getHistoryList() {
        return historyList;
    }

    public void loadHistory() {
        int userId = prefsHelper.getUserId();
        List<Request> list = historyRepository.getHistory(userId);
        historyList.setValue(list);
    }
}
