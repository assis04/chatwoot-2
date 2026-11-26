import {
  canSeeInSearch,
  conversationMatchesSearch,
  phoneSearchFragment,
} from '../conversationSearch';

const conversation = sender => ({ id: 1, meta: { sender } });

describe('phoneSearchFragment', () => {
  it('keeps the last 8 digits of a masked phone', () => {
    expect(phoneSearchFragment('(11) 97313-8202')).toBe('73138202');
    expect(phoneSearchFragment('+55 11 9 7313-8202')).toBe('73138202');
  });

  it('keeps short digit terms as they are', () => {
    expect(phoneSearchFragment('7313-8')).toBe('73138');
  });

  it('returns null for terms that are not phone-like', () => {
    expect(phoneSearchFragment('ana')).toBeNull();
    expect(phoneSearchFragment('CCPL00411')).toBeNull();
    expect(phoneSearchFragment('()-')).toBeNull();
  });
});

describe('conversationMatchesSearch', () => {
  const bel = conversation({
    name: 'Bel',
    phone_number: '+5511947295155',
    identifier: '5511947295155@s.whatsapp.net',
  });
  const ananda = conversation({ name: 'Ananda Lopes' });

  it('hides a conversation that does not match the term', () => {
    expect(conversationMatchesSearch(bel, 'ana')).toBe(false);
    expect(conversationMatchesSearch(ananda, 'ana')).toBe(true);
  });

  it('matches name, email, phone and identifier case-insensitively', () => {
    expect(conversationMatchesSearch(ananda, 'ANANDA')).toBe(true);
    expect(
      conversationMatchesSearch(conversation({ email: 'joao@x.com' }), 'joao@')
    ).toBe(true);
    expect(conversationMatchesSearch(bel, '947295')).toBe(true);
    expect(conversationMatchesSearch(bel, 's.whatsapp')).toBe(true);
  });

  it('matches a masked phone with and without the 9th digit', () => {
    expect(conversationMatchesSearch(bel, '(11) 94729-5155')).toBe(true);
    const oldFormat = conversation({ phone_number: '+551147295155' });
    expect(conversationMatchesSearch(oldFormat, '94729-5155')).toBe(true);
  });

  it('keeps everything when there is no term', () => {
    expect(conversationMatchesSearch(bel, '')).toBe(true);
    expect(conversationMatchesSearch(bel, '   ')).toBe(true);
  });

  it('does not match a conversation without sender data', () => {
    expect(conversationMatchesSearch({ id: 2 }, 'ana')).toBe(false);
  });
});

describe('canSeeInSearch', () => {
  const me = 7;
  const conv = (assigneeId, participantIds = []) => ({
    meta: {
      assignee: assigneeId ? { id: assigneeId } : null,
      participants: participantIds.map(id => ({ id })),
    },
  });
  const customRole = permissions => ({
    role: 'custom_role',
    permissions,
    userId: me,
  });

  it('lets administrators and plain agents see everything the server sent', () => {
    ['administrator', 'agent'].forEach(role => {
      expect(
        canSeeInSearch(conv(99), { role, permissions: [], userId: me })
      ).toBe(true);
    });
  });

  it('lets conversation_manage see conversations of other agents', () => {
    expect(canSeeInSearch(conv(99), customRole(['conversation_manage']))).toBe(
      true
    );
  });

  it('limits unassigned_manage to unassigned and own conversations', () => {
    const role = customRole([
      'conversation_unassigned_manage',
      'conversation_participating_manage',
    ]);
    expect(canSeeInSearch(conv(null), role)).toBe(true);
    expect(canSeeInSearch(conv(me), role)).toBe(true);
    expect(canSeeInSearch(conv(99, [me]), role)).toBe(false);
  });

  it('lets participating_manage find conversations they took part in', () => {
    const role = customRole(['conversation_participating_manage']);
    expect(canSeeInSearch(conv(me), role)).toBe(true);
    expect(canSeeInSearch(conv(null, [me, 3]), role)).toBe(true);
    expect(canSeeInSearch(conv(null, [3]), role)).toBe(false);
    expect(canSeeInSearch(conv(99), role)).toBe(false);
  });

  it('hides everything from a custom role without conversation permissions', () => {
    expect(canSeeInSearch(conv(me), customRole(['contact_manage']))).toBe(
      false
    );
  });
});
