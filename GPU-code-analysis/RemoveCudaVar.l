%option noyywrap nodefault yylineno
%x FUNCTIONPARAM
%x CUDAVARKIND

%{
  //这个文件应该不是由java文件生成的，直接可以编译成可执行文件使用
  //这个文件步入了第二次扫描的第二阶段，主要就是要处理所有的cuda直接相关变量和间接相关变量，并且记录下这些变量所在的行号
  //以便日后删除,注意，这里的行号是在一般的语句中这个变量和他最接近的下一个分号中的所有行号。
  //一开始我们肯定是扫描有没有Cuda的数据类型，并且把这些数据类型之后的那个变量名,然后将一个变量名列表返回
  //CUDA类型的类型现在我们仅能以cudaError_t为例，我们先用一个命名模式存起来。
  //为了防止用户在形参列表中折行，在匹配上函数的时候我们就要记录下来函数所在的行号
  int functionLine;
  extern int yylineno;
  //这里我们依旧需要加入表明小括号嵌套和大括号嵌套的东西，但是我们还需要一组变量来区分不同的小括号和大括号
  int nesting;
  int smallnesting;
  //一组变量区分不同的大括号和不同的小括号,二元组（braceId,nesting）可以唯一标识一个大括号题，小括号也是一样的道理
  int braceId;
  int parenthesesId;
  //在进入一个函数之前又需要一组形参记录当前函数所处braceId和parenthesesId记录下来，这样子才可以区分这个Cuda类型的变量是不是
  //真的出现的位置是在形参里
  int lastBranceId;
  int lastparenthesesId;

  //这个变量用来判断扫描到的函数是不是应该被删除
  int functionDel;

  //这个变量服务于CUDAVARKIND状态，用来判断是不是在函数中遇到的CUDA变量，以确定我们应该从CUDAVARKIND状态返回到哪种状态
  int functionReturn;

  //还有一个变量记录了上一个记录的“要求被删除的行的行号”
  int lastDeleteLine;
  //这个数组存储了所有要删除的行号
  int lineCount[10000];
  //这个变量存着数组的下一个空位的索引
  int lineCountIndex;
  //这个函数用来向数组中添加一个行号，还要添加一个这个变量所在的嵌套id和代码块嵌套级数，我们
  //的删除是有一个原则的，那就是只删除嵌套id一样、并且nesting比这个变量出现的位置要大的同名参数
  //这样子我们就可以尽可能防止误删
  void recordLineNumberAndVarName(int yylineno,char* varName, int nesting ,int BranceId);
  void recordLineNumber(int yylineno);
%}

%{
  //因为我们不删除间接相关的变量，并且我们在勾选的时候会保留所有的函数声明，所以我们采用了这样子的方式：
  //我们再进行一次定位，把所有cuda类型的的所有变量所在行登记一下，这一步在下一个文件的时候完成
  //这个文件中我们还要解决if和while的问题，首先就是if条件中的CUDA变量将会导致整个if以及后续的所有else，else if全部删除
  //如果在while中遇到cuda类型的变量的话那就直接删除整个while，并且可能还有之前的do。这个就是我们要处理的额外情况，因为其他的情况都是
  //删除一行，所以说我们只要好好搞定cuda类型在if和while括号里面的情况就好了

  //但是实际上这个东西只要在下个文件中的时候做就好了，我们定位到了所有要删除的行，只要我们检测到这一行里面有if，那么剩下的行只要连坐就好了。

%}

CUDAKIND ("cudaError_t")

%%
<CUDAVARKIND>[A-Za-z_]{1}[A-Za-z0-9_]* {
  //这里在匹配到一个CUDA的变量名的时候我们匹配到一个变量名,我们要记录下这个变量名的诸多东西
  //变量名##行号##nesting##BranceId
  printf("进入到CUDAVARKIND状态\n");
  recordLineNumberAndVarName(yylineno, yytext, nesting, braceId);
  if(functionReturn == 1){
    BEGIN FUNCTIONPARAM;
  }
  if(functionReturn == 0){
    BEGIN INITIAL;
  }
}

<CUDAVARKIND>(" ")  {
}

<CUDAVARKIND>\n|. {

}

[^A-Za-z_]{1}{CUDAKIND}/[^A-Za-z0-9]{1}  {
  //这里说明匹配到了一个cuda类型名，之后跟着的第一个英文名肯定是一个CUDA类型的变量名
  functionReturn = 0;
  BEGIN CUDAVARKIND;
}

[A-Za-z]{1}[A-Za-z0-9]*(" "|\t|\n)*"("  {
  //这个匹配遇到一个函数的情况
  printf("匹配到一个函数在第%d行\n",yylineno);
  functionLine = yylineno;
  lastBranceId = braceId;
  lastparenthesesId = parenthesesId;
  functionDel = 0;
  if(smallnesting == 0){
    parenthesesId++;
  }
  BEGIN FUNCTIONPARAM;
}

<FUNCTIONPARAM>[^A-Za-z_]{1}{CUDAKIND}/[^A-Za-z0-9]{1} {
  yytext = yytext - 1;
  printf("匹配到CUDA数据类型在第%d行\n",yylineno);
  if(parenthesesId == lastparenthesesId + 1){
    printf("检测到函数形参中的%s类型变量在第%d行\n",yytext,yylineno);
    functionDel = 1;
    //登记函数的声明开始到这个形参位置为所有行
    for(int i = functionLine ; i <= yylineno; i++){

      recordLineNumber(i);
    }
    //已经检测从发现函数到形参位置的所有行
    printf("已经检测从发现函数到形参位置的所有行\n");
  }else {
    //如果发现了CUDA的数据类型，并且发现这个数据类型不是形参的话那么直接记录并删除这一行
    recordLineNumber(yylineno);
    functionReturn = 1;
    BEGIN CUDAVARKIND;
  }
}



<FUNCTIONPARAM>")"(" "|\t|\n)*";"  {
  //这里匹配函数的声明，如果发现lastparenthesesId在这个时候仅增加过一次，那么就可以说明这个分号几乎是紧跟着形参列表的
  printf("检测到分号在第%d行\n",yylineno);
  printf("这个位置的parenthesesId = %d,lastparenthesesId = %d\n",parenthesesId,lastparenthesesId);
  if((parenthesesId == lastparenthesesId + 1)&&(nesting==0)){
    //退出函数状态
    printf("退出函数状态在第%d行\n",yylineno);
    BEGIN INITIAL;
  }
}

<FUNCTIONPARAM>"{" {
  if(functionDel == 1){
    recordLineNumber(yylineno);
  }
  if(nesting == 0){
    printf("----------braceId自增了在第%d行\n",yylineno);
    braceId++;
  }
  nesting++;

}

<FUNCTIONPARAM>"("  {
  if(functionDel == 1){
    recordLineNumber(yylineno);
  }
  if(smallnesting == 0){
    parenthesesId++;
  }
  smallnesting++;
}

<FUNCTIONPARAM>")"  {
  if(functionDel == 1){
    recordLineNumber(yylineno);
  }
  smallnesting--;
}

<FUNCTIONPARAM>"}"  {
  if(functionDel == 1){

    recordLineNumber(yylineno);
  }
  nesting--;
  if(nesting == 0){
    printf("检测到函数结束在第%d行\n",yylineno);
    BEGIN INITIAL;
  }
}

<FUNCTIONPARAM>.|\n  {
  //如果这是一个需要删除的函数，那么我们就需要把这一行记录在案
  if(functionDel == 1){
    recordLineNumber(yylineno);
  }
}

"{" {
  //接下来会有一系列在普通模式下对于smallnesting、nesting、parenthesesId、BranceId的修改
  if(nesting == 0){
    printf("----------braceId自增了在第%d行\n",yylineno);
    braceId++;
  }
  nesting++;
}

"(" {
  if(smallnesting == 0){
    parenthesesId++;
  }
  smallnesting++;
}

")" {
  smallnesting--;
}

"}"  {
  nesting--;
}

.|\n  {
}
%%
void recordLineNumber(int yylineno){
  if(yylineno > lastDeleteLine){
    printf("正在记录要删除的东西\n");
    lineCount[lineCountIndex] = yylineno;
    lineCountIndex++;
    lastDeleteLine = yylineno;
  }
}

void recordLineNumberAndVarName(int yylineno,char* varName, int nesting ,int BranceId){
  recordLineNumber(yylineno);
  //这里我们要在文件中做一些操作使用分号间隔，记录一些变量的nesting，BranceId，
  //这里记录的格式主要是varName##yylineno##nesting##BranceId
  fprintf(yyout,"%s##%d##%d##%d\n",varName,yylineno,nesting,BranceId);
}

int main(int argc, char *argv[]){
  yylineno = 1;
  functionLine = 0;
  parenthesesId = 0;
  braceId = 0;
  lastBranceId = 0;
  lastparenthesesId = 0;
  functionReturn = 0;
  /*首先把输入和输出文件规定好*/
  if(argc > 1){
    if(!(yyin = fopen(argv[1],"r"))){
      perror(argv[1]);
      return 1;
    }
    if(!(yyout = fopen(argv[2],"w"))){
      //这里定义的输出文件将会返回CUDA数据类型的变量名
      perror(argv[2]);
      return 1;
    }
  }

  printf("输入输出文件定位完毕，开始进行分析\n");


  yylex();

  printf("\n");
  for(int i = 0; i < lineCountIndex; i++){
    printf("%d,",lineCount[i]);
  }
  printf("\n");

}
