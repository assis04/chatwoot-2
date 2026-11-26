import { h } from 'vue';

// Fork Valcenter: desenha os segmentos { text, match } do helper/messageSearch.js;
// o trecho que casou vira <mark>. O conteudo vai sempre como texto (escapado pelo
// Vue), nunca como HTML — a mensagem e escrita pelo cliente.
const MARK_CLASS = 'px-px rounded-sm bg-n-amber-4 text-n-slate-12';

const HighlightedText = props =>
  props.segments.map((segment, index) =>
    segment.match
      ? h('mark', { key: index, class: MARK_CLASS }, segment.text)
      : segment.text
  );

HighlightedText.props = {
  segments: { type: Array, required: true },
};

export default HighlightedText;
