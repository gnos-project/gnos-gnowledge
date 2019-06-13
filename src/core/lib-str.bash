########
# FUNC #  STR
########


str::JoinStringByDelimiter () # $1:DELIMITER $2:STRING
{
    {
        local sep=$1 first=1 buf
        shift
        for word in "$@" ; do
            if [[ $first -eq 0 ]] ; then
                buf="$buf$sep$word"
            else
                buf="$word"
                first=0
            fi
        done
        echo "$buf"
    } 2>/dev/null
}

str::SplitStringByDelimiter () # $1:DELIMITER $2:STRING $3:ARRAY_NAME
{
  { IFS="$1" read -a $3 <<<"$2" ; } 2>/dev/null
}

str::SanitizeStringAllow () # $1:ALLOWED_CHARS $2:INPUT
{
    { echo -n "$2" | tr -c "$1"'_[:alnum:]' '-' ; } 2>/dev/null
}

str::SanitizeString () # $*:INPUT
{
    { str::SanitizeStringAllow "" "$*" ; } 2>/dev/null
}

str::GetWordCount ()
{
    { echo $# ; } 2>/dev/null
}

str::GetWordIndex () # $1:WORD $*:LIST
{
    {
        local cnt=0 word=$1 ; shift
        for w in $* ; do
            [[ "$w" == "$word" ]] && { echo -n $cnt ; return 0 ; }
            ((cnt++))
        done
        return 1
    } 2>/dev/null
}

str::InList ()  # $1:WORD $*:LIST
{
    {
        local word=$1 ; shift
        for w in $* ; do
            [[ "$w" == "$word" ]] && return 0
        done
        return 1
    } 2>/dev/null
}

str::RemoveWord () # $1:WORD $*:LIST
{
    {
        local buf word=$1 ; shift
        for w in $* ; do
            [[ "$w" == "$word" ]] && continue
            buf="$buf $w"
        done
        echo $buf
    } 2>/dev/null
}

str::SortWords () # $*:WORD
{
    {
          echo $*     \
        | tr " " "\n" \
        | sort -n     \
        | tr "\n" " "
    } 2>/dev/null
}
