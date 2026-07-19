'use strict';

// askLLM 自訂 UI 事件:把 question 的單行 TextBox 換成多行 textarea。
// 機制參考 Rj 模組:view 層 loaded 事件注入 HTML,ui.question.setValue() 回寫選項。
// jamovi 標準控制項沒有多行文字輸入(schema 僅單行 TextBox),此為官方唯一擴充管道。

const AREA_ID = 'askllm-question-area';
const LABEL_TEXT = 'Your question';

function getOption(ui, name) {
    try {
        let opt = ui[name];
        if (opt && typeof opt.value === 'function')
            return opt.value();
    } catch (e) { }
    return null;
}

// 找出 question 的原生單行輸入框。三重策略,依序:
// A) 以「Your question」Label 為 DOM 錨點,取其後第一個 input(零副作用,最穩)
// B) 唯一值比對:question 目前值非空且恰有一個 input 的值等於它
// C) 哨兵值定位:只在 Submit 未勾時使用(setValue 會觸發重跑,勾著時可能計費)
function findQuestionInput(ui, root) {
    let inputs = Array.from(root.querySelectorAll('input'));

    // A. Label 錨點
    let all = Array.from(root.querySelectorAll('*'));
    let label = all.find((el) =>
        el.children.length === 0 && el.textContent.trim() === LABEL_TEXT);
    if (label) {
        let after = inputs.find((inp) =>
            label.compareDocumentPosition(inp) & Node.DOCUMENT_POSITION_FOLLOWING);
        if (after)
            return after;
    }

    // B. 唯一值比對
    let orig = getOption(ui, 'question');
    if (orig !== null && orig !== '') {
        let matches = inputs.filter((i) => i.value === orig);
        if (matches.length === 1)
            return matches[0];
    }

    // C. 哨兵(僅 Submit 未勾)
    if (orig !== null && getOption(ui, 'submit') === false) {
        const SENTINEL = '__askllm_locator__';
        try {
            ui.question.setValue(SENTINEL);
            let inp = inputs.find((i) => i.value === SENTINEL);
            ui.question.setValue(orig);
            if (inp)
                return inp;
        } catch (e) { }
    }

    return null;
}

function buildTextarea(ui, initial) {
    let ta = document.createElement('textarea');
    ta.id = AREA_ID;
    ta.rows = 5;
    ta.value = initial || '';
    ta.placeholder = 'Type your question here / 在此輸入問題(可多行)';
    ta.style.cssText = [
        'width: 98%',
        'box-sizing: border-box',
        'min-height: 6em',
        'resize: vertical',
        'font: inherit',
        'padding: 6px',
        'margin: 4px 0 8px 0',
        'border: 1px solid #bbb',
        'border-radius: 3px',
        'display: block'
    ].join(';');
    let sync = () => {
        try { ui.question.setValue(ta.value); } catch (e) { }
    };
    ta.addEventListener('change', sync);
    ta.addEventListener('blur', sync);
    return ta;
}

function init(ui) {
    let root = ui.view.el;
    if (!root || root.querySelector('#' + AREA_ID))
        return;

    let inp = findQuestionInput(ui, root);
    let initial = getOption(ui, 'question');
    if ((initial === null || initial === '') && inp)
        initial = inp.value;
    if (initial === '__askllm_locator__')
        initial = '';

    let ta = buildTextarea(ui, initial);

    if (inp) {
        inp.style.display = 'none';
        inp.insertAdjacentElement('afterend', ta);
    } else {
        root.insertAdjacentElement('afterbegin', ta);
    }
}

module.exports = {

    loaded(ui) {
        // 控制項可能尚未渲染完成,延後一輪事件迴圈再注入
        setTimeout(() => { try { init(ui); } catch (e) { } }, 0);
    },

    updated(ui) {
        // 選項值由外部改變(如載入 .omv 存檔)時同步回 textarea;未注入過則補注入
        try {
            let root = ui.view.el;
            let ta = root ? root.querySelector('#' + AREA_ID) : null;
            if (!ta) {
                setTimeout(() => { try { init(ui); } catch (e) { } }, 0);
                return;
            }
            if (document.activeElement !== ta) {
                let val = getOption(ui, 'question');
                if (val !== null && val !== '__askllm_locator__')
                    ta.value = val;
            }
        } catch (e) { }
    }
};
