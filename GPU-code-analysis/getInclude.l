%option noyywrap nodefault yylineno
%x LINE
%x FUNCTION
%{
  extern int yylineno;
  int flag;
  char* headFileName[100];
  int fileCount;
  //这个变量是上一次匹配到需要的行号，我们把行号记录下来，然后读取这一行的下一行代码。
  int lastline;
%}

%%
^"#"line {
  //代码块负责找到一个line，然后将
  //printf("找到了一行我们需要的注释在第%d行\n", yylineno);
  //不管之前发生什么，进入line之前flag都要是0
  flag = 0;
  BEGIN LINE;
}

<FUNCTION>^"#"line {
  //printf("在匹配函数的过程当中重新匹配到了注释\n");
  //代码块负责找到一个line，然后将
  //printf("找到了一行我们需要的注释在第%d行\n", yylineno);
  //printf("进入LINE状态\n");
  flag = 0;
  BEGIN LINE;
}

<FUNCTION>^"#"  {
  //printf("匹配到了不需要的东西\n");
  //printf("进入INITIAL状态\n");
  BEGIN INITIAL;
}


<FUNCTION>. {
  if(lastline == yylineno -1){
    //printf("这里需要打印店东西\n");
    printf("%s",yytext);
  }
}

<FUNCTION>\n  {
  //printf("检测到回车lastline=%d,yylineno=%d\n",lastline,yylineno);
  if(lastline == yylineno -1){
    printf("%s",yytext);
  }
  if(lastline == yylineno -2){
    //printf("进入INITIAL状态\n");
    BEGIN INITIAL;
  }
}

<LINE>"nvidia gpu computing toolkit"\\\\"cuda"|"NVIDIA GPU Computing Toolkit"\\\\"CUDA"|"Microsoft Visual Studio ".{1,6}\\\\"VC"|"debug"|"microsoft visual studio".{1,6}\\\\"vc"  {
  //我们这里以windows为例，去除C语言的标准库和CUDA库的
  //printf("匹配到了标准库和CUDA库\n");
  BEGIN INITIAL;
}

<LINE>[A-Za-z0-9_\.]+".h"/\042  {
  //这里获取我们能够匹配到的头文件
  //printf("这里匹配到一个头文件%s在第%d行\n",yytext,yylineno);
  lastline = yylineno;
  //printf("进入FUNCTION状态\n");
  BEGIN FUNCTION;
}

<LINE>[A-Za-z0-9_\.]+".cu"/\042 {
  //这里获取我们能够匹配到的cu文件
  if(yylineno > 100)
  {
    //printf("这里匹配到一个cu文件%s\n在第%d行\n",yytext,yylineno);
    lastline = yylineno;
    //printf("进入FUNCTION状态\n");
    BEGIN FUNCTION;
  }

}

<LINE>[A-Za-z0-9_\.]+".c"/\042 {
  //这里获取我们能够匹配到的cu文件
  //printf("这里匹配到一个c文件%s\n在第%d行\n",yytext,yylineno);
  lastline = yylineno;
  //printf("进入FUNCTION状态\n");
  BEGIN FUNCTION;
}


<LINE>\042  {
  //printf("正在尝试是不是匹配上的引号\n");
  //通过判断经过的引号的个数来判断是不是应该退出LINE模式
  flag++;
  if (flag == 2){
    BEGIN INITIAL;
  }
}

<LINE>.|\n {}

. {}
\n  {}
%%
int main(int argc, char *argv[]){
  yylineno = 1;
  flag = 0;
  fileCount = 0;
  /*首先把输入和输出文件规定好*/
  if(argc > 1){
    if(!(yyin = fopen(argv[1],"r"))){
      perror(argv[1]);
      return 1;
    }
  }

  printf("输入输出文件定位完毕，开始进行分析\n");

  yylex();
}
