import re

import ply.lex
import ply.lex


# Usage
# python stripcomments.py input.tex > output.tex
# python stripcomments.py input.tex -e encoding > output.tex

# modified from https://gist.github.com/amerberg/a273ca1e579ab573b499

# Usage
# python stripcomments.py input.tex > output.tex
# python stripcomments.py input.tex -e encoding > output.tex

# Modification:
# 1. Preserve "\n" at the end of line comment
# 2. For \makeatletter \makeatother block, Preserve "%" 
#    if it is actually a comment, and trim the line
#    while preserve the "\n" at the end of the line. 
#    That is because remove the % some time will result in
#    compilation failure.

def strip_comments(source):
    tokens = (
        'PERCENT', 'BEGINCOMMENT', 'ENDCOMMENT',
        'BACKSLASH', 'CHAR', 'BEGINVERBATIM',
        'ENDVERBATIM', 'NEWLINE', 'ESCPCT',
        'MAKEATLETTER', 'MAKEATOTHER',
    )
    states = (
        ('makeatblock', 'exclusive'),
        ('makeatlinecomment', 'exclusive'),
        ('linecomment', 'exclusive'),
        ('commentenv', 'exclusive'),
        ('verbatim', 'exclusive')
    )

    # Deal with escaped backslashes, so we don't
    # think they're escaping %
    def t_BACKSLASH(t):
        r"\\\\"
        return t

    # Leaving all % in makeatblock
    def t_MAKEATLETTER(t):
        r"\\makeatletter"
        t.lexer.begin("makeatblock")
        return t

    # One-line comments
    def t_PERCENT(t):
        r"\%"
        t.lexer.begin("linecomment")

    # Escaped percent signs
    def t_ESCPCT(t):
        r"\\\%"
        return t

    # Comment environment, as defined by verbatim package
    def t_BEGINCOMMENT(t):
        r"\\begin\s*{\s*comment\s*}"
        t.lexer.begin("commentenv")

    # Verbatim environment (different treatment of comments within)
    def t_BEGINVERBATIM(t):
        r"\\begin\s*{\s*verbatim\s*}"
        t.lexer.begin("verbatim")
        return t

    # Any other character in initial state we leave alone
    def t_CHAR(t):
        r"."
        return t

    def t_NEWLINE(t):
        r"\n"
        return t

    # End comment environment
    def t_commentenv_ENDCOMMENT(t):
        r"\\end\s*{\s*comment\s*}"
        # Anything after \end{comment} on a line is ignored!
        t.lexer.begin('linecomment')

    # Ignore comments of comment environment
    def t_commentenv_CHAR(t):
        r"."
        pass

    def t_commentenv_NEWLINE(t):
        r"\n"
        pass

    # End of verbatim environment
    def t_verbatim_ENDVERBATIM(t):
        r"\\end\s*{\s*verbatim\s*}"
        t.lexer.begin('INITIAL')
        return t

    # Leave contents of verbatim environment alone
    def t_verbatim_CHAR(t):
        r"."
        return t

    def t_verbatim_NEWLINE(t):
        r"\n"
        return t

    # End a % comment when we get to a new line
    def t_linecomment_ENDCOMMENT(t):
        r"\n"
        t.lexer.begin("INITIAL")

        # Newline at the end of a line comment is presevered.
        return t

    # Ignore anything after a % on a line
    def t_linecomment_CHAR(t):
        r"."
        pass

    def t_makeatblock_MAKEATOTHER(t):
        r"\\makeatother"
        t.lexer.begin('INITIAL')
        return t

    def t_makeatblock_BACKSLASH(t):
        r"\\\\"
        return t

    # Escaped percent signs in makeatblock
    def t_makeatblock_ESCPCT(t):
        r"\\\%"
        return t

    # presever % in makeatblock
    def t_makeatblock_PERCENT(t):
        r"\%"
        t.lexer.begin("makeatlinecomment")
        return t

    def t_makeatlinecomment_NEWLINE(t):
        r"\n"
        t.lexer.begin('makeatblock')
        return t

    # Leave contents of makeatblock alone
    def t_makeatblock_CHAR(t):
        r"."
        return t

    def t_makeatblock_NEWLINE(t):
        r"\n"
        return t

    # For bad characters, we just skip over it
    def t_ANY_error(t):
        t.lexer.skip(1)

    lexer = ply.lex.lex()
    lexer.input(source)
    return u"".join([tok.value for tok in lexer])


START_PATTERN = 'egin{document}'
END_PATTERN = 'nd{document}'


def removeMacro(string):
    """
        This method searches for defs, newcommands, edef, gdef,xdef, DeclareMathOperators and renewcommand 
        and gets the macro structure out of it. Number 
    """

    str_no_comments = strip_comments(string)
    subs_regexp = []
    list_regexp = []
    # You can manually specify the number of replacements by changing the 4th argument
    shouldParse = True
    final_doc = []
    for line in str_no_comments.split('\n'):
        if shouldParse:
            if re.search(START_PATTERN, line):
                shouldParse = False
                for reg in list_regexp:
                    expanded_regexp = build_subs_regexp(reg)
                    if expanded_regexp:
                        subs_regexp.append(expanded_regexp)

            else:
                result = parseMacroStructure(line)
                if result:
                    list_regexp.append(result)
        else:
            if re.search(END_PATTERN, line):
                final_doc.append(line)
                break
            else:
                ### Perform substitutions  
                line = recursiveExpansion(line, subs_regexp)
        final_doc.append(line)

    # print(subs_regexp)
    print('\n'.join(final_doc))


def parseMacroStructure(line):
    regexp = r"\\(.*command|DeclareMathOperator|def|edef|xdef|gdef)({|)(\\[a-zA-Z]+)(}|)(\[([0-9])\]|){(.*(?=\}))\}.*$"
    result = re.search(regexp, line)
    if result:
        macroStructure = {
            'command_type': result.group(1),
            'macro_name': result.group(3),
            'separator_open': result.group(2),
            'separator_close': result.group(4),
            'number_of_inputs': result.group(6),
            'raw_replacement': result.group(7),
        }
        return macroStructure
    else:
        return None


def build_subs_regexp(reg):
    """
        This method creates the replacement text for the macro.
        TODO: 
            - extend this to any input macro
            - recursively expand raw_replacements (up to any degree)
            - build tests            
    """
    if re.search('declare', reg["command_type"]):

        print()
    else:
        if not reg["number_of_inputs"]:
            # The macro has no inputs
            return {'sub': reg["raw_replacement"], 'reg': '\\' + reg["macro_name"] + '(?![a-zA-Z])', }
        else:
            # The macro has one or more inputs
            print()


def recursiveExpansion(line, available_regexp):
    for subs in available_regexp:
        if not (re.search(subs["reg"], line)):
            # print(line,'does not match',subs["reg"])
            continue
        else:
            # print(line,'does not match',subs["reg"])
            line = re.sub(subs["reg"], subs["sub"], line)
        # print('after: '+line)
    for subs in available_regexp:
        if not (not (re.search(subs["reg"], line))):
            return recursiveExpansion(line, available_regexp)
        else:
            continue
    return line


string = r"""
\documentclass[11pt,reqno]{amsart}
\providecommand{\opt}[1]{\framebox[3ex][c]{#1}} %casella per risposte multiple
\DeclareMathOperator{\dom}{dom}  %% dominio di una funzione
\DeclareMathOperator{\re}{Re}  %% parte reale
\DeclareMathOperator{\im}{Im}  %% parte immaginaria
\newcommand{\erre}{\mathbb{R}} %insieme dei numeri reali
\newcommand{\ci}{\mathbb{C}} % insieme dei numeri complessi
\DeclareMathOperator{\sign}{sign}  %% segno
\DeclareMathOperator{\de}{d\!} % d dritto
\DeclareMathOperator{\res}{Res} % residuo
\newcommand{\F}{\mathcal{F}} % trasformata di Fourier
\renewcommand{\L}{\mathcal{L}} % trasformata di Laplace
\newcommand{\LL}{\L^2} % trasformata di Laplace
\newcommand{\LLL}{(\L^2+(\LL)^3} % trasformata di Laplace
\newcommand{\weird}[3]{\sum_{n = #1}^{#2} \F(#3) - 7 +\frac{#1}{#2}}
\def\indicator{\mathbf{1}}


\begin{document}
\noindent
Student's surname and name \underline{\hspace{68.5ex}}

\vspace{1.5ex}

\noindent
Student's number \underline{\hspace{80ex}}

%%%%%%%%%% DOMANDE A RISPOSTA MULTIPLA

\vspace{8ex}
$$\L(3) + \F(4) + \LL(6) + (\LLL)^7 \indicator_{5}  \weird ab\res{c}$$
\noindent
\end{document}
"""
removeMacro(string)
