import 'package:eschool_saas_staff/data/repositories/chatRepository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

enum ChatReadMessageStatus { initial, loading, success, failure }

class ChatReadMessageCubit extends Cubit<ChatReadMessageStatus> {
  ChatReadMessageCubit() : super(ChatReadMessageStatus.initial);

  final _chatRepository = ChatRepository();

  void readMessage({required List<int> messagesIds}) async {
    emit(ChatReadMessageStatus.loading);

    try {
      await _chatRepository.readMessage(messagesIds: messagesIds);
      if (!isClosed) emit(ChatReadMessageStatus.success);
    } catch (e) {
      if (!isClosed) emit(ChatReadMessageStatus.failure);
    }
  }
}
