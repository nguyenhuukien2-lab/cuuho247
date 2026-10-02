import 'dart:async';
import 'package:cuu_ho_247/app/app_controller.dart';
import 'package:cuu_ho_247/app/user_session.dart';
import 'package:cuu_ho_247/screens/history_details_screen.dart';
import 'package:cuu_ho_247/services/customer_request_review_service.dart';
import 'package:cuu_ho_247/services/request_details_service.dart';
import 'package:cuu_ho_247/widgets/customer_request_review_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'history_details_test.dart' as support;

CustomerRequestReview result(
        {int rating = 4, String? comment = 'Hỗ trợ nhanh'}) =>
    CustomerRequestReview(
        id: 'review',
        requestId: 'request',
        customerId: 'owner',
        rating: rating,
        comment: comment,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026));

class ReviewsFake implements CustomerRequestReviewRepository {
  CustomerRequestReview? value;
  bool failLoad = false, failSubmit = false;
  int loads = 0, submits = 0;
  int? submittedRating;
  String? submittedComment;
  Completer<CustomerRequestReview>? pending;
  @override
  Future<CustomerRequestReview?> load(String id) async {
    loads++;
    if (failLoad) throw Exception('offline');
    return value;
  }

  @override
  Future<CustomerRequestReview> submit(String id,
      {required int rating, String? comment}) async {
    submits++;
    submittedRating = rating;
    submittedComment = comment;
    if (failSubmit) throw Exception('offline');
    if (pending != null) return pending!.future;
    return value = result(rating: rating, comment: comment);
  }
}

Future<AppController> mount(WidgetTester tester, ReviewsFake repo,
    {String status = 'completed'}) async {
  tester.view.physicalSize = const Size(420, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final controller = AppController();
  addTearDown(controller.dispose);
  await tester.pumpWidget(MaterialApp(
      home: HistoryDetailsScreen(
          requestId: 'request',
          controller: controller,
          repository: support.DetailsFake(
              RequestDetails({'id': 'request', 'status': status}, [])),
          photoRepository: support.PhotosFake(),
          reviewRepository: repo)));
  await tester.pumpAndSettle();
  return controller;
}

Future<void> fill(WidgetTester tester) async {
  await tester.tap(find.byTooltip('4 sao'));
  await tester.enterText(find.byType(TextField), 'Hỗ trợ nhanh');
  tester.testTextInput.hide();
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => UserSession.userId = 'owner');
  tearDown(UserSession.clear);
  testWidgets('completed without review shows stars, comment and submit',
      (tester) async {
    final repo = ReviewsFake();
    await mount(tester, repo);
    expect(find.text('Đánh giá sau cứu hộ'), findsOneWidget);
    expect(find.text('Gửi đánh giá'), findsOneWidget);
    for (var star = 1; star <= 5; star++) {
      expect(find.byTooltip('$star sao'), findsOneWidget);
    }
    expect(repo.loads, 1);
  });
  testWidgets('completed with review shows submitted result', (tester) async {
    await mount(tester, ReviewsFake()..value = result());
    expect(find.text('Đã đánh giá: 4/5 sao'), findsOneWidget);
    expect(find.text('Hỗ trợ nhanh'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Gửi đánh giá'), findsNothing);
  });
  for (final status in [
    'cancelled',
    'searching',
    'accepted',
    'arriving',
    'in_progress'
  ]) {
    testWidgets('$status has no review UI or read', (tester) async {
      final repo = ReviewsFake();
      await mount(tester, repo, status: status);
      expect(find.byType(CustomerRequestReviewCard), findsNothing);
      expect(find.text('Gửi đánh giá'), findsNothing);
      expect(repo.loads, 0);
    });
  }
  testWidgets(
      'submit error preserves rating/comment and retry updates immediately',
      (tester) async {
    final repo = ReviewsFake()..failSubmit = true;
    await mount(tester, repo);
    await fill(tester);
    await tester.tap(find.text('Gửi đánh giá'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Hỗ trợ nhanh');
    expect(find.byIcon(Icons.star), findsNWidgets(4));
    expect(find.text('Thử lại'), findsOneWidget);
    repo.failSubmit = false;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(repo.submittedRating, 4);
    expect(repo.submittedComment, 'Hỗ trợ nhanh');
    expect(find.text('Đã đánh giá: 4/5 sao'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });
  testWidgets('submit loading disables double submission then displays result',
      (tester) async {
    final repo = ReviewsFake()..pending = Completer<CustomerRequestReview>();
    await mount(tester, repo);
    await fill(tester);
    await tester.tap(find.text('Gửi đánh giá'));
    await tester.pump();
    expect(find.text('Đang gửi…'), findsOneWidget);
    await tester.tap(find.text('Đang gửi…'));
    expect(repo.submits, 1);
    repo.pending!.complete(result());
    await tester.pumpAndSettle();
    expect(find.text('Đã đánh giá: 4/5 sao'), findsOneWidget);
  });
  testWidgets('load failure retries before exposing form', (tester) async {
    final repo = ReviewsFake()..failLoad = true;
    await mount(tester, repo);
    expect(find.text('Thử tải lại'), findsOneWidget);
    expect(find.text('Gửi đánh giá'), findsNothing);
    repo.failLoad = false;
    await tester.tap(find.text('Thử tải lại'));
    await tester.pumpAndSettle();
    expect(find.text('Gửi đánh giá'), findsOneWidget);
  });
  testWidgets('changed session discards late submit result', (tester) async {
    final repo = ReviewsFake()..pending = Completer<CustomerRequestReview>();
    final controller = await mount(tester, repo);
    await fill(tester);
    await tester.tap(find.text('Gửi đánh giá'));
    await tester.pump();
    UserSession.userId = 'other';
    controller.selectTab(4);
    await tester.pump();
    repo.pending!.complete(result());
    await tester.pumpAndSettle();
    expect(find.text('Đã đánh giá: 4/5 sao'), findsNothing);
    expect(find.text('Hỗ trợ nhanh'), findsNothing);
  });
}
