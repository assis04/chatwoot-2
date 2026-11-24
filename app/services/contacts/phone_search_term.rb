# Fork Valcenter: busca por telefone tolerante a formatacao e ao 9o digito.
#
# contacts.phone_number e sempre E.164 ("+5511973138202"), mas o agente cola o
# numero do jeito que ve: "(11) 97313-8202", "97313-8202", "+55 11 9 7313-8202".
# Com ILIKE cru nada disso casa. Aqui o termo que PARECE telefone vira so os
# digitos; a partir de 8 digitos usamos os 8 ultimos, que identificam o numero
# com ou sem DDI/DDD e com ou sem o 9o digito (o WhatsApp guarda celulares
# antigos sem o 9).
#
# O espelho no front e helper/conversationSearch.js: as duas regras precisam
# andar juntas, senao a lista esconde resultado que o servidor devolveu.
module Contacts::PhoneSearchTerm
  PHONE_LIKE = /\A[\d\s().+-]+\z/
  SIGNIFICANT_DIGITS = 8

  # Trecho de digitos para casar com contacts.phone_number via LIKE, ou nil
  # quando o termo nao parece telefone.
  def self.fragment(term)
    term = term.to_s.strip
    return unless term.match?(PHONE_LIKE)

    digits = term.gsub(/\D/, '')
    return if digits.empty?

    digits.length >= SIGNIFICANT_DIGITS ? digits.last(SIGNIFICANT_DIGITS) : digits
  end
end
