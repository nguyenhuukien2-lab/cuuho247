package com.example.roadside.ui.history;

import android.os.Bundle;

import androidx.appcompat.app.AppCompatActivity;
import androidx.lifecycle.ViewModelProvider;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;

import com.example.roadside.R;

public class HistoryActivity extends AppCompatActivity {

    private RecyclerView rvHistory;
    private HistoryAdapter adapter;
    private HistoryViewModel viewModel;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_history);

        rvHistory = findViewById(R.id.rvHistory);
        rvHistory.setLayoutManager(new LinearLayoutManager(this));

        adapter = new HistoryAdapter();
        rvHistory.setAdapter(adapter);

        viewModel = new ViewModelProvider(this).get(HistoryViewModel.class);
        viewModel.getHistoryList().observe(this, adapter::setRequests);

        viewModel.loadHistory();
    }
}
