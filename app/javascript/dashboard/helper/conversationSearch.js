// Fork Valcenter: espelho no front da busca da lista de conversas
// (ConversationFinder#filter_by_query + Contacts::PhoneSearchTerm no backend).
//
// A busca roda no servidor, mas a lista desenha o que esta no store, e o store
// recebe conversas que NAO vieram da busca: a conversa aberta (o ConversationView
// busca de novo quando ela some da lista), eventos em tempo real e o refresh da
// reconexao. Sem este filtro, buscar "ana" mostrava a "Bel" que estava aberta.
// As duas regras precisam andar juntas: se o front for mais estrito que o servidor,
// a lista esconde resultado valido.

const PHONE_LIKE = /^[\d\s().+-]+$/;
const SIGNIFICANT_DIGITS = 8;

const onlyDigits = value => String(value || '').replace(/\D/g, '');

// Trecho de digitos que identifica o telefone com ou sem DDI/DDD e com ou sem o
// 9o digito; null quando o termo nao parece telefone.
export const phoneSearchFragment = term => {
  const trimmed = String(term || '').trim();
  if (!PHONE_LIKE.test(trimmed)) return null;

  const digits = onlyDigits(trimmed);
  if (!digits) return null;

  return digits.length >= SIGNIFICANT_DIGITS
    ? digits.slice(-SIGNIFICANT_DIGITS)
    : digits;
};

// Fork Valcenter: a busca procura em TUDO que o agente pode ver, sem a aba, a
// caixa ou o status. Quem decide e o Conversations::PermissionFilterService; isto
// espelha a mesma hierarquia (manage > unassigned_manage > participating_manage),
// inclusive a participacao, para a busca achar a conversa que o agente atendeu e
// que perdeu o dono ao ser resolvida. A lista normal continua no applyRoleFilter.
export const canSeeInSearch = (conversation, { role, permissions, userId }) => {
  if (['administrator', 'agent'].includes(role)) return true;
  if (permissions.includes('conversation_manage')) return true;

  const assigneeId = conversation?.meta?.assignee?.id;
  const isMine = assigneeId === userId;

  if (permissions.includes('conversation_unassigned_manage')) {
    return !assigneeId || isMine;
  }
  if (permissions.includes('conversation_participating_manage')) {
    const participants = conversation?.meta?.participants || [];
    return (
      isMine || participants.some(participant => participant.id === userId)
    );
  }
  return false;
};

export const conversationMatchesSearch = (conversation, term) => {
  const needle = String(term || '')
    .trim()
    .toLowerCase();
  if (!needle) return true;

  const sender = conversation?.meta?.sender || {};
  const fields = [
    sender.name,
    sender.email,
    sender.phone_number,
    sender.identifier,
  ];
  if (
    fields.some(field =>
      String(field || '')
        .toLowerCase()
        .includes(needle)
    )
  ) {
    return true;
  }

  const fragment = phoneSearchFragment(needle);
  return (
    Boolean(fragment) && onlyDigits(sender.phone_number).includes(fragment)
  );
};
