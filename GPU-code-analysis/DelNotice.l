%option noyywrap nodefault yylineno
%%

^"#" {
  int c;
  while((c = input()) && c != '\n');
  printf("去除第%d行注释\n" , yylineno);
  yylineno++;
} /*现在要去除的是一整行注释*/

\n  {ECHO;yylineno++;}

. {
    printf("获取字符%s\n", yytext);
    ECHO;
  } /*剩下的匹配项全部写到文件中*/

%%

int main(int argc, char *argv[]){
  /*首先把输入和输出文件规定好*/
  if(argc > 2){
    if(!(yyin = fopen(argv[1],"r"))){
      perror(argv[1]);
      return 1;
    }
    if(!(yyout = fopen(argv[2],"w"))){
      perror(argv[2]);
      return 1;
    }
  }

  printf("输入输出文件定位完毕，开始进行分析\n");
  yylineno = 1;
  yylex();
}
