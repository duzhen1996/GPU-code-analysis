%option noyywrap nodefault yylineno
%{
  extern int yylineno;
%}
%%

^\r\n {
  printf("正在第%d行,获取空行\n", yylineno);
}

^\n\r {
  printf("正在第%d行,获取空行\n", yylineno);
}

^\n {
  printf("正在第%d行,获取空行\n", yylineno);
}

^\r {
  printf("正在第%d行,获取空行\n", yylineno);
}

\n\r  {
  printf("正在第%d行\n", yylineno);
  ECHO;
}

\r\n  {
  printf("正在第%d行\n", yylineno);
  ECHO;
}

\n  {
  printf("正在第%d行\n", yylineno);
  ECHO;
}

. {
    //printf("正在第%d行\n", yylineno);
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
    printf("输入文件定位完毕\n");
    if(!(yyout = fopen(argv[2],"w"))){
      perror(argv[2]);
      return 1;
    }
    printf("输出文件定位完毕\n");
  }

  printf("输入输出文件定位完毕，开始进行分析\n");
  yylineno = 1;
  yylex();
}
