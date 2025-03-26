import 'dart:io';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:eschool_saas_staff/cubits/chat/chatDeleteMessageCubit.dart';
import 'package:eschool_saas_staff/cubits/chat/chatMessagesCubit.dart';
import 'package:eschool_saas_staff/cubits/chat/chatReadMessageCubit.dart';
import 'package:eschool_saas_staff/cubits/chat/chatSendMessageCubit.dart';
import 'package:eschool_saas_staff/cubits/chat/socketSettingsCubit.dart';
import 'package:eschool_saas_staff/data/models/chatMessage.dart';
import 'package:eschool_saas_staff/ui/screens/home/widgets/chatContainer/widgets/selectAttachementBottomsheet.dart';
import 'package:eschool_saas_staff/ui/widgets/customCircularProgressIndicator.dart';
import 'package:eschool_saas_staff/ui/widgets/errorContainer.dart';
import 'package:eschool_saas_staff/utils/constants.dart';
import 'package:eschool_saas_staff/utils/utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    required this.receiverId,
    required this.receiverName,
    required this.receiverImage,
    this.classSection,
    super.key,
  });

  final int receiverId;
  final String receiverName;
  final String receiverImage;
  final String? classSection;

  @override
  State<ChatScreen> createState() => _ChatScreenState();

  static Widget getRouteInstance() {
    final args = Get.arguments as Map<String, dynamic>;

    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => ChatMessagesCubit()),
        BlocProvider(create: (_) => SendMessageCubit()),
        BlocProvider(create: (_) => ChatDeleteMessageCubit()),
        BlocProvider(create: (_) => ChatReadMessageCubit()),
      ],
      child: ChatScreen(
        receiverId: args['receiverId'] as int,
        receiverName: args['receiverName'] as String,
        receiverImage: args['receiverImage'] as String,
        classSection: args['classSection'] as String?,
      ),
    );
  }

  static Map<String, dynamic> buildArguments({
    required int receiverId,
    required String receiverName,
    required String receiverImage,
    String? classSection,
  }) {
    return {
      'receiverId': receiverId,
      'receiverName': receiverName,
      'receiverImage': receiverImage,
      'classSection': classSection,
    };
  }
}

class _ChatScreenState extends State<ChatScreen> {
  final _scrollController = ScrollController();
  final _messageController = TextEditingController();

  var _isMessageLongPressed = false;
  final _selectedMessages = <int>{};

  var selectedAttachments = <XFile>[];

  var unreadMessages = <ChatMessage>[];
  var unreadCount = 0;

  String? lastMessage;
  DateTime? lastMessageTime;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    _fetchChatMessages();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    super.dispose();
  }

  void _fetchChatMessages() {
    context
        .read<ChatMessagesCubit>()
        .fetchChatMessages(receiverId: widget.receiverId);
  }

  void _scrollListener() {
    if (_scrollController.position.maxScrollExtent ==
        _scrollController.offset) {
      if (context.read<ChatMessagesCubit>().hasMore) {
        context
            .read<ChatMessagesCubit>()
            .fetchMoreChatMessages(receiverId: widget.receiverId);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SocketSettingCubit, SocketSettingState>(
      listener: (context, state) {
        if (state is SocketMessageReceived) {
          if (widget.receiverId.toString() == state.from) {
            context.read<ChatMessagesCubit>().messageReceived(
                  from: state.from,
                  message: state.message,
                );
          }
        }
      },
      child: Scaffold(
        body: Column(
          children: [
            _buildAppbar(),
            Expanded(
              child: BlocConsumer<SendMessageCubit, SendMessageState>(
                listener: (context, state) {
                  if (state.status == SendMessageStatus.success) {
                    final message = state.message!;

                    /// Update the message locally in the cubit and send it to the socket.
                    context.read<ChatMessagesCubit>().messageSent(message);
                    context.read<SocketSettingCubit>().sendMessage(
                          userId: message.senderId,
                          receiverId: widget.receiverId,
                          message: message,
                        );

                    _messageController.clear();
                    selectedAttachments.clear();
                    setState(() {
                      lastMessage = message.message;
                      lastMessageTime = message.updatedAt;
                    });
                  }
                },
                builder: (context, state) {
                  return BlocListener<ChatReadMessageCubit,
                      ChatReadMessageStatus>(
                    listener: (context, state) {
                      if (state == ChatReadMessageStatus.success) {
                        context
                            .read<ChatMessagesCubit>()
                            .readMessages(unreadMessages);

                        unreadCount += unreadMessages.length;
                      }
                    },
                    child: BlocConsumer<ChatMessagesCubit, ChatMessagesState>(
                      listener: (context, state) {
                        if (state is ChatMessagesFetchSuccess) {
                          unreadMessages = state.response.messages
                              .where(
                                (msg) =>
                                    msg.senderId == widget.receiverId &&
                                    msg.readAt == null,
                              )
                              .toList();

                          if (unreadMessages.isNotEmpty) {
                            context.read<ChatReadMessageCubit>().readMessage(
                                  messagesIds:
                                      unreadMessages.map((e) => e.id).toList(),
                                );
                          }
                        }
                      },
                      builder: (context, state) {
                        if (state is ChatMessagesFetchFailure) {
                          return ErrorContainer(
                            errorMessage: state.message,
                            onTapRetry: _fetchChatMessages,
                          );
                        }
                        if (state is ChatMessagesFetchSuccess) {
                          final messages = state.response.messages;

                          // Show Date Header for last message and
                          // When date of message is different from
                          // next message.
                          bool showDateHeader(int idx) {
                            if (idx == messages.length - 1) return true;

                            final currDate = messages[idx].createdAt;
                            final nextDate = messages[idx + 1].createdAt;

                            return !currDate.isSameDayAs(nextDate);
                          }

                          return LayoutBuilder(
                            builder: (context, constraints) {
                              return RawScrollbar(
                                controller: _scrollController,
                                child: ListView.builder(
                                  reverse: true,
                                  controller: _scrollController,
                                  padding: EdgeInsets.only(
                                    top: appContentHorizontalPadding,
                                    right: appContentHorizontalPadding,
                                    left: appContentHorizontalPadding,
                                    // bottom: appContentHorizontalPadding,
                                  ),
                                  itemCount: messages.length,
                                  itemBuilder: (context, index) {
                                    final message = messages[index];

                                    return Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (index == messages.length - 1 &&
                                            state.loadMore)
                                          Center(
                                            child:
                                                CustomCircularProgressIndicator(
                                              indicatorColor: Theme.of(context)
                                                  .colorScheme
                                                  .primary,
                                            ),
                                          ),

                                        // like Today, Yesterday, 30 Aug 2024 etc.
                                        if (showDateHeader(index))
                                          _buildDateHeader(
                                            message.createdAt,
                                          ),

                                        ///
                                        GestureDetector(
                                          child: _buildMessageContainer(
                                            boxConstraints: constraints,
                                            message: message,
                                          ),
                                          onLongPress: () {
                                            if (message.senderId !=
                                                widget.receiverId) {
                                              setState(() {
                                                _isMessageLongPressed = true;
                                              });
                                            }
                                          },
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              );
                            },
                          );
                        }

                        return Center(
                          child: CustomCircularProgressIndicator(
                            indicatorColor:
                                Theme.of(context).colorScheme.primary,
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
            if (selectedAttachments.isNotEmpty)
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Theme.of(context).colorScheme.surface,
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: selectedAttachments
                          .map(
                            (e) => Container(
                              width: 120,
                              height: 100,
                              margin: const EdgeInsetsDirectional.only(
                                start: 10,
                                end: 10,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  e.path.endsWith('.jpg') ||
                                          e.path.endsWith('.jpeg') ||
                                          e.path.endsWith('.png')
                                      ? ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          child: Image.file(
                                            File(e.path),
                                            fit: BoxFit.fitWidth,
                                          ),
                                        )
                                      : Column(
                                          mainAxisSize: MainAxisSize.min,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.insert_drive_file_outlined,
                                              size: 24,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .surface,
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              e.name,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .surface,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),

                                  ///
                                  Align(
                                    alignment: AlignmentDirectional.topEnd,
                                    child: InkWell(
                                      onTap: () {
                                        setState(() {
                                          selectedAttachments.remove(e);
                                        });
                                      },
                                      child: Container(
                                        height: 24,
                                        width: 24,
                                        margin:
                                            const EdgeInsetsDirectional.only(
                                          end: 8,
                                          top: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.white,
                                          border: Border.all(
                                            color: Colors.red,
                                            width: 1,
                                          ),
                                        ),
                                        alignment: Alignment.center,
                                        child: const Icon(
                                          Icons.close_rounded,
                                          color: Colors.red,
                                          size: 15,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
              ),

            ///
            Align(
              alignment: Alignment.bottomCenter,
              child: _buildSendMessage(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateHeader(DateTime date) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Text(
        Utils.getTranslatedLabel(date.relativeFormatedDate),
        style: TextStyle(
          fontSize: 12.0,
          fontWeight: FontWeight.w500,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildAppbar() {
    final colorScheme = Theme.of(context).colorScheme;

    Widget messagesSelectAppBar() {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconButton(
            onPressed: () => Get.back(result: unreadCount),
            icon: Icon(
              Utils.isRTLEnabled(context)
                  ? CupertinoIcons.arrow_right
                  : CupertinoIcons.arrow_left,
            ),
          ),
          if (_selectedMessages.isNotEmpty) ...[
            const SizedBox(width: 20),
            Text(
              '${_selectedMessages.length} ${Utils.getTranslatedLabel("selected")}',
              style: TextStyle(
                fontSize: 18.0,
                color: Theme.of(context).scaffoldBackgroundColor,
              ),
            ),
            const Spacer(),
            BlocListener<ChatDeleteMessageCubit, ChatDeleteMessageStatus>(
              listener: (context, status) {
                if (status == ChatDeleteMessageStatus.success) {
                  context.read<ChatMessagesCubit>().deleteMessages(
                        _selectedMessages.toList(),
                      );

                  setState(() {
                    _isMessageLongPressed = false;
                    _selectedMessages.clear();
                  });
                }
              },
              child: IconButton(
                onPressed: () {
                  context.read<ChatDeleteMessageCubit>().deleteMessage(
                        messagesIds: _selectedMessages.toList(),
                      );
                },
                icon: Icon(
                  Icons.delete_outlined,
                  color: Theme.of(context).colorScheme.primary,
                  opticalSize: 24,
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
        ],
      );
    }

    void onBack() {
      Get.back(result: (
        lastMessage: lastMessage,
        lastMessageTime: lastMessageTime,
        unreadCount: unreadCount,
      ));
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;

        onBack();
      },
      child: Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colorScheme.tertiary)),
          color: colorScheme.surface,
        ),
        height: kToolbarHeight + MediaQuery.of(context).padding.top,
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top,
          bottom: 8,
        ),
        width: double.maxFinite,
        alignment: Alignment.center,
        child: _isMessageLongPressed
            ? messagesSelectAppBar()
            : Row(
                children: [
                  IconButton(
                    onPressed: onBack,
                    icon: Icon(
                      Utils.isRTLEnabled(context)
                          ? CupertinoIcons.arrow_right
                          : CupertinoIcons.arrow_left,
                    ),
                  ),
                  const SizedBox(width: 8.0),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: colorScheme.tertiary,
                    ),
                    padding: EdgeInsets.zero,
                    margin: EdgeInsets.zero,
                    alignment: Alignment.center,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: CachedNetworkImage(
                        imageUrl: widget.receiverImage,
                        fit: BoxFit.cover,
                        width: 48,
                        height: 48,
                      ),
                    ),
                  ),

                  ///
                  const SizedBox(width: 16.0),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.receiverName,
                        style: const TextStyle(
                          fontSize: 14.0,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4.0),
                      if (widget.classSection != null)
                        Text(
                          widget.classSection!,
                          style: const TextStyle(
                            fontSize: 12.0,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  Future<String> _downloadFromUrl(String url) async {
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/Media/${url.split('/').last}';

    await Dio().download(url, path);

    return path;
  }

  Widget _buildMessageContainer({
    required BoxConstraints boxConstraints,
    required ChatMessage message,
  }) {
    const radius = 10.0;

    final sendByMe = message.senderId != widget.receiverId;

    final isRTL = Directionality.of(context).name == TextDirection.rtl.name;

    /// FlipAngleX determines which side of the screen the message will be shown.
    /// We show Message on the right side of the screen if it is sent by the user.
    /// and on the left side of the screen if it is sent by the other user.
    /// Now, with RTL language, we do the inverse of the above logic.
    bool flipAngleX = isRTL ? !sendByMe : sendByMe;

    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Align(
        alignment: sendByMe
            ? AlignmentDirectional.centerEnd
            : AlignmentDirectional.centerStart,
        child: Column(
          crossAxisAlignment:
              sendByMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isMessageLongPressed && sendByMe) ...[
                  Checkbox(
                    value: _selectedMessages.contains(message.id),
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _selectedMessages.add(message.id);
                        } else {
                          _selectedMessages.remove(message.id);
                        }
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                ],
                Transform.flip(
                  flipX: flipAngleX,
                  child: CustomPaint(
                    painter: MessageContainerPainter(
                      radius: radius,
                      color:
                          sendByMe ? colorScheme.surface : colorScheme.primary,
                    ),
                    child: Container(
                      padding: EdgeInsetsDirectional.only(
                        start: isRTL ? 10 : 20,
                        end: isRTL ? 20 : 10,
                        bottom: 10,
                        top: 10,
                      ),
                      constraints: BoxConstraints(
                        maxWidth: boxConstraints.maxWidth * (0.75),
                      ),
                      child: Transform.flip(
                        flipX: flipAngleX,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (message.attachments.isNotEmpty)
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ...message.attachments.map(
                                    (e) {
                                      return Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 10),
                                        child: (e.fileType == 'jpg' ||
                                                e.fileType == 'jpeg' ||
                                                e.fileType == 'png')
                                            ? Stack(
                                                children: [
                                                  ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                    child: CachedNetworkImage(
                                                      width: 256,
                                                      height: 256,
                                                      imageUrl: e.file,
                                                      fit: BoxFit.cover,
                                                    ),
                                                  ),

                                                  /// Download button
                                                  PositionedDirectional(
                                                    top: 15,
                                                    end: 15,
                                                    child: InkWell(
                                                      onTap: () async {
                                                        final path =
                                                            await _downloadFromUrl(
                                                                e.file);

                                                        OpenFilex.open(path);
                                                      },
                                                      child: Icon(
                                                        Icons.download_rounded,
                                                        size: 24,
                                                        color: sendByMe
                                                            ? colorScheme
                                                                .secondary
                                                            : Theme.of(context)
                                                                .scaffoldBackgroundColor,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              )
                                            : Row(
                                                children: [
                                                  Icon(
                                                    Icons
                                                        .insert_drive_file_outlined,
                                                    size: 24,
                                                    color: sendByMe
                                                        ? colorScheme.secondary
                                                        : Theme.of(context)
                                                            .scaffoldBackgroundColor,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      e.file.split('/').last,
                                                      maxLines: 2,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        color: sendByMe
                                                            ? colorScheme
                                                                .secondary
                                                            : Theme.of(context)
                                                                .scaffoldBackgroundColor,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  InkWell(
                                                    onTap: () async {
                                                      final path =
                                                          await _downloadFromUrl(
                                                              e.file);

                                                      OpenFilex.open(path);
                                                    },
                                                    child: Icon(
                                                      Icons.download_rounded,
                                                      size: 24,
                                                      color: sendByMe
                                                          ? colorScheme
                                                              .secondary
                                                          : Theme.of(context)
                                                              .scaffoldBackgroundColor,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                      );
                                    },
                                  )
                                ],
                              ),

                            ///
                            if (message.message != null)
                              Text(
                                message.message ?? "",
                                style: TextStyle(
                                  color: sendByMe
                                      ? colorScheme.secondary
                                      : Theme.of(context)
                                          .scaffoldBackgroundColor,
                                ),
                              )
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  Utils.hourMinutesDateFormat
                      .format(message.createdAt.toLocal()),
                  style: TextStyle(
                    fontSize: 12.0,
                    color: colorScheme.secondary.withOpacity(0.75),
                  ),
                ),
                const SizedBox(width: 2.5),
                Icon(
                  message.readAt != null
                      ? Icons.done_all_rounded
                      : Icons.done_rounded,
                  size: 15,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSendMessage() {
    void onTapSendMessage() {
      if (_messageController.text.isEmpty && selectedAttachments.isEmpty) {
        return;
      }

      context.read<SendMessageCubit>().sendMessage(
            receiverId: widget.receiverId,
            message: _messageController.text,
            files: selectedAttachments.isNotEmpty ? selectedAttachments : null,
          );
    }

    return Container(
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface),
      padding:
          const EdgeInsetsDirectional.symmetric(vertical: 20, horizontal: 20),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 100),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(50),
          color: Theme.of(context).scaffoldBackgroundColor,
        ),
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 10),
        child: Row(
          children: [
            InkWell(
              onTap: () {
                Utils.showBottomSheet(
                  child: SelectAttachmentBottomSheet(
                    updateAttachments: (attachments) {
                      setState(() {
                        selectedAttachments = attachments;
                      });
                    },
                  ),
                  context: context,
                );
              },
              child: CircleAvatar(
                radius: 15.5,
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: Transform.rotate(
                  transformHitTests: true,
                  angle: -pi / 2,
                  child: Icon(
                    Icons.attachment,
                    size: 20.0,
                    color: Theme.of(context).scaffoldBackgroundColor,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                maxLines: null,
                controller: _messageController,
                decoration: InputDecoration(
                  contentPadding: EdgeInsets.zero,
                  hintText: Utils.getTranslatedLabel("typeMessageHere"),
                  border: InputBorder.none,
                  hintStyle: TextStyle(
                    fontSize: 14.0,
                    color: Theme.of(context)
                        .colorScheme
                        .secondary
                        .withOpacity(0.75),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            BlocBuilder<SendMessageCubit, SendMessageState>(
                builder: (context, state) {
              return state.status == SendMessageStatus.sending
                  ? SizedBox(
                      height: 20,
                      child: CustomCircularProgressIndicator(
                        widthAndHeight: 20,
                        indicatorColor: Theme.of(context).colorScheme.secondary,
                      ),
                    )
                  : InkWell(
                      onTap: onTapSendMessage,
                      child: CircleAvatar(
                        radius: 15.5,
                        backgroundColor: Colors.transparent,
                        child: Icon(
                          Icons.send,
                          color: Theme.of(context)
                              .colorScheme
                              .secondary
                              .withOpacity(0.75),
                        ),
                      ),
                    );
            }),
          ],
        ),
      ),
    );
  }
}

class MessageContainerPainter extends CustomPainter {
  final double radius;
  final Color color;

  const MessageContainerPainter({this.radius = 10, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.fill;

    Path path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width - radius, 0);

    ///[First top end curve]
    path.quadraticBezierTo(size.width, 0, size.width, radius);
    path.lineTo(size.width, size.height - radius);

    ///[Second bottom end curve]
    path.quadraticBezierTo(
        size.width, size.height, size.width - radius, size.height);

    path.lineTo(radius * 2, size.height);

    ///[Third bottom start curve]
    path.quadraticBezierTo(radius, size.height, radius, size.height - radius);

    path.lineTo(radius, radius);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
