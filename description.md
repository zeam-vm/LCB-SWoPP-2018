# はじめに

Node.jsでは，コールバックを用いてI/Oを非同期的に扱ってノンプリエンプティブなマルチタスクにする機構，Nodeプログラミングモデルが備わっている\cite{Node}．これにより，ウェブサーバーのメモリ使用量を格段に減らすことができ，同時セッション最大数やレイテンシが改善される\cite{NodeBenchmarks}．

もしNodeプログラミングモデルと同様の機構を，Javascriptよりパフォーマンスの良いプログラミング言語で実装したならば，ウェブサーバーの性能を格段に向上させることができる．そこで，我々は \Cpp とElixir \cite{Elixir} の2つのプログラミング言語を選んで実装を試みた． \Cpp を選んだのは，RFIDのような極端に小規模で消費電力の少ないような電子回路を用いてIoTデバイスを構築することを意図し，できるだけ小さなメモリ容量で実現でき，かつ \Cpp 11 はNodeプログラミングモデルの実現に必要な匿名関数を備えているからである．Elixirを選んだのは，Elixirで書かれたウェブサーバーフレームワークであるPhoenixを用いることで，極めてレスポンス性の高いウェブサーバーを構築できる \cite{Elixir16} からである．

我々の \Cpp への実装を Zackernel と称し，Elixir への実装を軽量コールバックスレッドと称している．	これらを組合わせることで，世界中にばらまいた膨大な数のRFIDによる極小IoTデバイスと，それらから随時リクエストを受け付けるIoTサーバーからなるIoTシステムを構築することができる．

本報告では，Zackernel と軽量コールバックスレッドをどのように実装したのかを紹介し，メモリ消費量に焦点を当てて評価を行なう．

本報告のこの後の構成は次のとおりである．第2章では着想の元となったNodeプログラミングモデルについて紹介する．第3章ではZackernelの設計と実装を，第4章では軽量コールバックスレッドの設計と実装をそれぞれ示す．第5章ではメモリ消費量の評価を行う．最後に第6章でまとめと将来課題について述べる．

# Nodeプログラミングモデル

Nodeプログラミングモデル\cite{Node}

# Zackernel

# 軽量コールバックスレッド


# 評価

軽量コールバックスレッドのメモリ消費量を，通常のプロセスを用いた場合と比較する評価実験を行なった．Elixir にはメモリ消費量を測定するために `:erlang.memory` という関数が用意されている．この関数は全体のメモリ量やプロセスで使用しているメモリ量などを集計することができる．本研究では，軽量コールバックスレッドもしくはプロセスを一定数新規作成する前後の全体のメモリ量の変化を計測した．作成するスレッドもしくはプロセスの数は100, 1000, 2000, 5000, 10000の5通りで測定した．これらの測定結果を最小2乗法で傾きを求めることで，1スレッドもしくは1プロセスあたりの使用メモリ量を測定した．実験で用いた環境を\tabref{tab:environment}に示す．

\begin{table}[t]
\centering
\caption{実行環境}
\ecaption{Runtime Environment}
\label{tab:environment}
\begin{tabular}{l|l}
                       & Mac Pro (Mid 2010)     \\ \hline
OS                     & macOS Sierra 10.12.6   \\
Elixir                 & 1.6.1 (OTP 20.3.6)     \\
\end{tabular}
\end{table}



実験結果を\tabref{tab:results}と\figref{fig:results}に示す．それぞれの相関係数は軽量コールバックスレッドの場合で0.99284，プロセスの場合で0.99998であったので，実験結果は良好であったと考えられる．傾きより，軽量コールバックスレッドの場合で1スレッドあたり1332バイト，プロセスの場合で1プロセスあたり2835バイト消費していることがわかった．すなわち，軽量コールバックスレッドはプロセスの約半分のメモリ消費量である．


\begin{table}[tb]
\centering
\caption{実験結果: 軽量コールバックスレッドとプロセスのメモリ消費量の比較(表)}
\ecaption{Results: Table of Comparison of Memory Size of Light-weight Callback Threads and Processes}
\label{tab:results}
\begin{tabular}{r
>{\columncolor[HTML]{C0C0C0}}r r}
\multicolumn{1}{l}{Num. of Tasks} & \multicolumn{1}{l}{\cellcolor[HTML]{C0C0C0}CallBack (bytes)} & \multicolumn{1}{l}{Process (bytes)} \\
100                                             & 76144                                                        & 358848                              \\
1000                                            & 881656                                                       & 2877360                             \\
2000                                            & 1496296                                                      & 5636232                             \\
5000                                            & 5734120                                                      & 14160616                            \\
10000                                           & 13004640                                                     & 28402248                           
\end{tabular}
\end{table}

# まとめと将来課題




\begin{figure*}[t]
\centering
\includegraphicS[width=0.6\linewidth]{memory-callback-process.png}
\caption{実験結果: 軽量コールバックスレッドとプロセスのメモリ消費量の比較(散布図)}
\ecaption{Results: Scatterplot of Comparison of Memory Size of Light-weight Callback Threads and Processes}
\label{fig:results}
\end{figure*}


