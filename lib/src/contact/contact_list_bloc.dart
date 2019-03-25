/*
 * OPEN-XCHANGE legal information
 *
 * All intellectual property rights in the Software are protected by
 * international copyright laws.
 *
 *
 * In some countries OX, OX Open-Xchange and open xchange
 * as well as the corresponding Logos OX Open-Xchange and OX are registered
 * trademarks of the OX Software GmbH group of companies.
 * The use of the Logos is not covered by the Mozilla Public License 2.0 (MPL 2.0).
 * Instead, you are allowed to use these Logos according to the terms and
 * conditions of the Creative Commons License, Version 2.5, Attribution,
 * Non-commercial, ShareAlike, and the interpretation of the term
 * Non-commercial applicable to the aforementioned license is published
 * on the web site https://www.open-xchange.com/terms-and-conditions/.
 *
 * Please make sure that third-party modules and libraries are used
 * according to their respective licenses.
 *
 * Any modifications to this package must retain all copyright notices
 * of the original copyright holder(s) for the original code used.
 *
 * After any such modifications, the original and derivative code shall remain
 * under the copyright of the copyright holder(s) and/or original author(s) as stated here:
 * https://www.open-xchange.com/legal/. The contributing author shall be
 * given Attribution for the derivative code and a license granting use.
 *
 * Copyright (C) 2016-2020 OX Software GmbH
 * Mail: info@open-xchange.com
 *
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
 * or FITNESS FOR A PARTICULAR PURPOSE. See the Mozilla Public License 2.0
 * for more details.
 */

import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:delta_chat_core/delta_chat_core.dart';
import 'package:ox_talk/src/contact/contact_list_event.dart';
import 'package:ox_talk/src/contact/contact_list_state.dart';
import 'package:ox_talk/src/data/repository.dart';
import 'package:ox_talk/src/data/repository_manager.dart';
import 'package:ox_talk/src/data/repository_stream_handler.dart';
import 'package:rxdart/rxdart.dart';

class ContactListBloc extends Bloc<ContactListEvent, ContactListState> {
  final Repository<Contact> contactRepository = RepositoryManager.get(RepositoryType.contact);
  RepositoryStreamHandler repositoryStreamHandler;
  List<int> validContactIds = List();
  List<int> blockedContactIds = List();

  @override
  ContactListState get initialState => ContactListStateInitial();

  @override
  Stream<ContactListState> mapEventToState(ContactListState currentState, ContactListEvent event) async* {
    if (event is RequestContacts) {
      yield ContactListStateLoading();
      try {
        setupContactListener();
        setupContacts();
      } catch (error) {
        yield ContactListStateFailure(error: error.toString());
      }
    } else if (event is ContactsChanged) {
      List<int> resultValidContactIds = List();
      List<int> resultValidContactLastUpdateValues = List();
      for (int index = 0; index < validContactIds.length; index++) {
        var contact = contactRepository.get(validContactIds[index]);
        resultValidContactIds.add(contact.getId());
        resultValidContactLastUpdateValues.add(contact.lastUpdate);
      }
      yield ContactListStateSuccess(contactIds: resultValidContactIds, contactLastUpdateValues: resultValidContactLastUpdateValues);
    } else if (event is RequestBlockedContacts) {
      yield ContactListStateLoading();
      try {
        setupBlockedContacts();
      } catch (error) {
        yield ContactListStateFailure(error: error.toString());
      }
    } else if (event is BlockedContactsChanged) {
      List<int> resultBlockedContactIds = List();
      List<int> resultBlockedContactLastUpdateValues = List();
      for (int index = 0; index < blockedContactIds.length; index++) {
        var contact = contactRepository.get(blockedContactIds[index]);
        resultBlockedContactIds.add(contact.getId());
        resultBlockedContactLastUpdateValues.add(contact.lastUpdate);
      }
      yield ContactListStateSuccess(contactIds: resultBlockedContactIds, contactLastUpdateValues: resultBlockedContactLastUpdateValues);
    }
  }

  @override
  void dispose() {
    contactRepository.removeListener(repositoryStreamHandler);
    super.dispose();
  }

  void setupContactListener() async {
    repositoryStreamHandler = RepositoryStreamHandler(Type.publish, Event.contactsChanged, _dispatchContactsChanged);
    contactRepository.addListener(repositoryStreamHandler);
  }

  void _dispatchContactsChanged() async {
    await _updateValidContactIds();
    dispatch(ContactsChanged());
  }

  Future _updateValidContactIds() async {
    Context _context = Context();
    validContactIds = List.from(await _context.getContacts(2, null));
  }

  void setupContacts() async {
    await _updateValidContactIds();
    contactRepository.putIfAbsent(ids: validContactIds);
    dispatch(ContactsChanged());
  }

  void setupBlockedContacts() async {
    Context context = Context();
    blockedContactIds = List.from(await context.getBlockedContacts());
    dispatch(BlockedContactsChanged());
  }
}
